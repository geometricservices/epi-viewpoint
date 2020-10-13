defmodule EpicenterWeb.ProfileLive do
  use EpicenterWeb, :live_view

  import EpicenterWeb.IconView, only: [arrow_down_icon: 0, arrow_right_icon: 2]
  import EpicenterWeb.LiveHelpers, only: [assign_defaults: 2, assign_page_title: 2, noreply: 1, ok: 1]

  alias Epicenter.Accounts
  alias Epicenter.AuditLog
  alias Epicenter.Cases
  alias Epicenter.Cases.Person
  alias Epicenter.Format

  def mount(%{"id" => person_id}, session, socket) do
    if connected?(socket),
      do: Cases.subscribe_to_people()

    person = Cases.get_person(person_id)

    socket
    |> assign_defaults(session)
    |> assign_page_title(Format.person(person))
    |> assign_person(person)
    |> assign_users()
    |> ok()
  end

  def handle_info({:people, updated_people}, socket) do
    updated_people
    |> Enum.find(&(&1.id == socket.assigns.person.id))
    |> case do
      nil -> socket
      updated_person -> assign_person(socket, updated_person)
    end
    |> noreply()
  end

  def handle_event("form-change", %{"user" => "-unassigned-"}, socket),
    do: handle_event("form-change", %{"user" => nil}, socket)

  def handle_event("form-change", %{"user" => user_id}, socket) do
    {:ok, [updated_person]} =
      Cases.assign_user_to_people(
        user_id: user_id,
        people_ids: [socket.assigns.person.id],
        audit_meta: %AuditLog.Meta{
          author_id: socket.assigns.current_user.id,
          reason_action: AuditLog.Revision.update_assignment_action(),
          reason_event: AuditLog.Revision.profile_selected_assignee_event()
        }
      )

    Cases.broadcast_people([updated_person])

    {:noreply, assign_person(socket, updated_person)}
  end

  def assign_person(socket, person) do
    updated_person = person |> Cases.preload_lab_results() |> Cases.preload_addresses() |> Cases.preload_assigned_to()
    assign(socket, person: updated_person)
  end

  defp assign_users(socket),
    do: socket |> assign(users: Accounts.list_users())

  # # #

  def age(%Person{dob: dob}) do
    Date.diff(Date.utc_today(), dob) |> Integer.floor_div(365)
  end

  def is_unassigned?(person) do
    person.assigned_to == nil
  end

  def email_addresses(person) do
    person
    |> Cases.preload_emails()
    |> Map.get(:emails)
    |> Enum.map(& &1.address)
  end

  def is_selected?(user, person) do
    user == person.assigned_to
  end

  def phone_numbers(person) do
    person
    |> Cases.preload_phones()
    |> Map.get(:phones)
    |> Enum.map(&Format.phone/1)
  end

  def string_or_unknown(value) do
    if Euclid.Exists.present?(value),
      do: value,
      else: unknown_value()
  end

  def list_or_unknown(values) do
    if Euclid.Exists.present?(values) do
      Phoenix.HTML.Tag.content_tag :ul do
        Enum.map(values, &Phoenix.HTML.Tag.content_tag(:li, &1))
      end
    else
      unknown_value()
    end
  end

  def unknown_value do
    Phoenix.HTML.Tag.content_tag(:span, "Unknown", class: "unknown")
  end
end
