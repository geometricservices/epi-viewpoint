defmodule EpicenterWeb.ProfileEditLive do
  use EpicenterWeb, :live_view

  import EpicenterWeb.IconView, only: [plus_icon: 0, arrow_down_icon: 0, back_icon: 0, trash_icon: 0]
  import EpicenterWeb.LiveHelpers, only: [assign_defaults: 2, assign_page_title: 2, noreply: 1, ok: 1]

  alias Epicenter.AuditLog
  alias Epicenter.Cases
  alias Epicenter.DateParser
  alias Epicenter.Extra
  alias Epicenter.Format

  @confirmation_text "Your updates have not been saved. Discard updates?"

  def mount(%{"id" => id}, session, socket) do
    socket = socket |> assign_defaults(session)

    person =
      Cases.get_person(id)
      |> Cases.preload_emails()
      |> Cases.preload_phones()
      |> Cases.preload_addresses()

    changeset = person |> Cases.change_person(%{})

    socket
    |> assign_page_title("#{Format.person(person)} (edit)")
    |> assign(changeset: update_dob_field_for_display(changeset))
    |> assign(person: person)
    |> assign(preferred_language_is_other: false)
    |> assign_confirmation_prompt()
    |> ok()
  end

  def handle_event("add-address", _value, socket) do
    existing_addresses = socket.assigns.changeset |> Extra.Changeset.get_field_from_changeset(:addresses)
    addresses = existing_addresses |> Enum.concat([Cases.change_address(%Cases.Address{}, %{})])

    changeset = socket.assigns.changeset |> Ecto.Changeset.put_assoc(:addresses, addresses)
    socket |> assign(changeset: changeset |> Extra.Changeset.clear_validation_errors()) |> noreply()
  end

  def handle_event("add-email", _value, socket) do
    existing_emails = socket.assigns.changeset |> Extra.Changeset.get_field_from_changeset(:emails)
    emails = existing_emails |> Enum.concat([Cases.change_email(%Cases.Email{}, %{})])

    changeset = socket.assigns.changeset |> Ecto.Changeset.put_assoc(:emails, emails)
    socket |> assign(changeset: changeset |> Extra.Changeset.clear_validation_errors()) |> noreply()
  end

  def handle_event("add-phone", _value, socket) do
    existing_phones = socket.assigns.changeset |> Extra.Changeset.get_field_from_changeset(:phones)
    phones = existing_phones |> Enum.concat([Cases.change_phone(%Cases.Phone{}, %{})])

    changeset = socket.assigns.changeset |> Ecto.Changeset.put_assoc(:phones, phones)
    socket |> assign(changeset: changeset |> Extra.Changeset.clear_validation_errors()) |> noreply()
  end

  def handle_event("form-change", %{"person" => %{"preferred_language" => "Other"} = person_params}, socket) do
    socket |> assign(preferred_language_is_other: true) |> update_assigns_given_user_input(person_params) |> noreply()
  end

  def handle_event("form-change", %{"person" => person_params} = _params, socket) do
    socket |> assign(preferred_language_is_other: false) |> update_assigns_given_user_input(person_params) |> noreply()
  end

  def handle_event("remove-email", %{"email-index" => email_index_param}, socket) do
    email_index = email_index_param |> Euclid.Extra.String.to_integer()

    existing_emails = socket.assigns.changeset |> Extra.Changeset.get_field_from_changeset(:emails)
    emails = existing_emails |> List.delete_at(email_index)

    changeset = socket.assigns.changeset |> Ecto.Changeset.put_assoc(:emails, emails)
    {:noreply, assign(socket, changeset: changeset |> Extra.Changeset.clear_validation_errors())}
  end

  def handle_event("remove-phone", %{"phone-index" => phone_index_param}, socket) do
    phone_index = phone_index_param |> Euclid.Extra.String.to_integer()

    existing_phones = socket.assigns.changeset |> Extra.Changeset.get_field_from_changeset(:phones)
    phones = existing_phones |> List.delete_at(phone_index)

    changeset = socket.assigns.changeset |> Ecto.Changeset.put_assoc(:phones, phones)
    {:noreply, assign(socket, changeset: changeset |> Extra.Changeset.clear_validation_errors())}
  end

  def handle_event("save", %{"person" => person_params}, socket) do
    person_params =
      person_params
      |> update_dob_field_for_changeset()
      |> clean_up_languages()
      |> remove_blank_email_addresses()
      |> remove_blank_phone_numbers()
      |> remove_blank_addresses()

    socket.assigns.person
    |> Cases.update_person(
      {person_params,
       %AuditLog.Meta{
         author_id: socket.assigns.current_user.id,
         reason_action: AuditLog.Revision.update_profile_action(),
         reason_event: AuditLog.Revision.edit_profile_saved_event()
       }}
    )
    |> case do
      {:ok, person} ->
        {:noreply, socket |> push_redirect(to: Routes.profile_path(socket, EpicenterWeb.ProfileLive, person))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, update_dob_field_for_display(changeset))}
    end
  end

  # # #

  def clean_up_languages(%{"preferred_language" => "Other"} = person_params),
    do: person_params |> Map.put("preferred_language", person_params |> Map.get("other_specified_language"))

  def clean_up_languages(person_params), do: person_params

  def has_field?(changeset, field) do
    case changeset |> Ecto.Changeset.fetch_field(field) do
      :error -> false
      {_, []} -> false
      _ -> true
    end
  end

  def phone_types(),
    do: [{"Unknown", nil}, {"Cell", "cell"}, {"Home", "home"}, {"Work", "work"}]

  def preferred_languages(current \\ nil) do
    has_current = Euclid.Exists.present?(current)

    first = [
      {"English", "English"},
      {"Spanish", "Spanish"}
    ]

    middle =
      [
        {"Arabic", "Arabic"},
        {"Bengali", "Bengali"},
        {"Chinese (Cantonese)", "Chinese (Cantonese)"},
        {"Chinese (Mandarin)", "Chinese (Mandarin)"},
        {"French", "French"},
        {"Haitian Creole", "Haitian Creole"},
        {"Hebrew", "Hebrew"},
        {"Hindi", "Hindi"},
        {"Italian", "Italian"},
        {"Korean", "Korean"},
        {"Polish", "Polish"},
        {"Russian", "Russian"},
        {"Swahili", "Swahili"},
        {"Yiddish", "Yiddish"}
      ]
      |> case do
        languages when has_current -> [{current, current} | languages]
        languages -> languages
      end
      |> Enum.sort_by(&elem(&1, 0))

    last = [{"Other", "Other"}]

    (first ++ middle ++ last) |> Enum.uniq()
  end

  def states() do
    ~w{AL AK AS AZ AR CA CO CT DE DC FL GA GO HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MP MT NE NV NH NJ NM NY NC ND OH OK OR PA PR RI SC SD TN TX UT VT VA VI WA WV WI WY}
  end

  def remove_blank_email_addresses(%{"emails" => email_params} = person_params) do
    updated_email_params =
      email_params
      |> Enum.reject(fn {_index, %{"address" => address}} -> Euclid.Exists.blank?(address) end)
      |> Map.new()

    person_params |> Map.put("emails", updated_email_params)
  end

  def remove_blank_email_addresses(person_params),
    do: person_params

  def remove_blank_phone_numbers(%{"phones" => phone_params} = person_params) do
    updated_phone_params =
      phone_params
      |> Enum.reject(fn {_index, %{"number" => number}} -> Euclid.Exists.blank?(number) end)
      |> Map.new()

    person_params |> Map.put("phones", updated_phone_params)
  end

  def remove_blank_phone_numbers(person_params),
    do: person_params

  def remove_blank_addresses(%{"addresses" => address_params} = person_params) do
    updated_address_params =
      address_params
      |> Enum.reject(fn {_index, address} ->
        %{"street" => street, "city" => city, "postal_code" => postal_code} = address
        Euclid.Exists.blank?(street) and Euclid.Exists.blank?(city) and Euclid.Exists.blank?(postal_code)
      end)
      |> Map.new()

    person_params |> Map.put("addresses", updated_address_params)
  end

  def remove_blank_addresses(person_params),
    do: person_params

  # # #

  defp assign_confirmation_prompt(socket) do
    prompt =
      case socket.assigns.changeset do
        nil -> nil
        changeset -> if Map.drop(changeset.changes, [:dob]) == %{}, do: nil, else: @confirmation_text
      end

    socket |> assign(confirmation_prompt: prompt)
  end

  defp update_assigns_given_user_input(socket, person_params) do
    person_params = person_params |> update_dob_field_for_changeset() |> clean_up_languages()

    changeset =
      socket.assigns.person
      |> Cases.change_person(person_params)
      |> Map.put(:action, :insert)

    socket
    |> assign(changeset: changeset |> update_dob_field_for_display() |> Extra.Changeset.clear_validation_errors())
    |> assign_confirmation_prompt()
  end

  defp reformat_date(changeset, field) do
    case Ecto.Changeset.fetch_field(changeset, field) do
      {:error} -> changeset
      {_, date} -> Ecto.Changeset.put_change(changeset, field, Format.date(date))
    end
  end

  defp update_dob_field_for_changeset(person_params) do
    case DateParser.parse_mm_dd_yyyy(person_params["dob"]) do
      {:ok, date} -> %{person_params | "dob" => date}
      {:error, _} -> person_params
    end
  end

  defp update_dob_field_for_display(changeset) do
    if changeset.errors |> Keyword.has_key?(:dob) do
      Extra.Changeset.rewrite_changeset_error_message(changeset, :dob, "please enter dates as mm/dd/yyyy")
    else
      reformat_date(changeset, :dob)
    end
  end
end
