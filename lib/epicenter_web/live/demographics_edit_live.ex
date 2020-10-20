defmodule EpicenterWeb.DemographicsEditLive do
  use EpicenterWeb, :live_view

  import EpicenterWeb.LiveHelpers, only: [assign_defaults: 2, assign_page_title: 2, noreply: 1, ok: 1]

  alias Epicenter.AuditLog
  alias Epicenter.Cases
  alias Epicenter.Extra
  alias Epicenter.Format

  def mount(%{"id" => id}, session, socket) do
    socket = socket |> assign_defaults(session)
    person = Cases.get_person(id)
    changeset = person |> Cases.change_person(%{}) |> hard_code_gender_identity()

    socket
    |> assign_page_title("#{Format.person(person)} (edit)")
    |> assign(changeset: changeset)
    |> assign(person: person)
    |> ok()
  end

  def handle_event("form-change", form_state, socket) do
    changeset = socket.assigns.changeset
    old_form_state = expected_person_params_from_changeset(changeset)

    old_major_ethnicity = old_form_state && old_form_state.major
    new_major_ethnicity = form_state["person"]["ethnicity"]["major"]

    old_detailed_ethnicity = old_form_state && old_form_state.detailed
    new_detailed_ethnicity = form_state["person"]["ethnicity"]["detailed"]

    new_ethnicity =
      cond do
        old_major_ethnicity != new_major_ethnicity and old_major_ethnicity == "hispanic_latinx_or_spanish_origin" ->
          %{major: new_major_ethnicity, detailed: %{}}

        old_detailed_ethnicity != new_detailed_ethnicity and Euclid.Exists.present?(new_detailed_ethnicity) ->
          %{major: "hispanic_latinx_or_spanish_origin", detailed: new_detailed_ethnicity}

        true ->
          form_state["person"]["ethnicity"]
      end

    new_changeset =
      socket.assigns.person
      |> Cases.change_person(form_state)
      |> Ecto.Changeset.delete_change(:ethnicity)
      |> Ecto.Changeset.put_change(:ethnicity, Euclid.Extra.Map.deep_atomize_keys(new_ethnicity))

    socket = socket |> assign(:changeset, new_changeset)
    noreply(socket)
  end

  def handle_event("submit", %{"person" => person_params} = _params, socket) do
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
        socket
        |> push_redirect(to: Routes.profile_path(socket, EpicenterWeb.ProfileLive, person))
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp hard_code_gender_identity(%{data: data} = changeset) do
    %{changeset | data: %{data | gender_identity: ["Female"]}}
  end

  def gender_identity_options() do
    [
      "Declined to answer",
      "Female",
      "Transgender woman/trans woman/male-to-female (MTF)",
      "Male",
      "Transgender man/trans man/female-to-male (FTM)",
      "Genderqueer/gender nonconforming neither exclusively male nor female",
      "Additional gender category (or other)"
    ]
  end

  def major_ethnicity_options() do
    [
      {"unknown", "Unknown"},
      {"declined_to_answer", "Declined to answer"},
      {"not_hispanic_latinx_or_spanish_origin", "Not Hispanic, Latino/a, or Spanish origin"},
      {"hispanic_latinx_or_spanish_origin", "Hispanic, Latino/a, or Spanish origin"}
    ]
  end

  @detailed_ethnicity_mapping %{
    "hispanic_latinx_or_spanish_origin" => [
      {"mexican_mexican_american_chicanx", "Mexican, Mexican American, Chicano/a"},
      {"puerto_rican", "Puerto Rican"},
      {"cuban", "Cuban"},
      {"another_hispanic_latinx_or_spanish_origin", "Another Hispanic, Latino/a or Spanish origin"}
    ]
  }

  def detailed_ethnicity_options(major_ethnicity),
    do: @detailed_ethnicity_mapping[major_ethnicity] || []

  def detailed_ethnicity_checked(%Ecto.Changeset{} = changeset, detailed_ethnicity),
    do: changeset |> Extra.Changeset.get_field_from_changeset(:ethnicity) |> detailed_ethnicity_checked(detailed_ethnicity)

  def detailed_ethnicity_checked(%{detailed: nil}, _detailed_ethnicity),
    do: false

  def detailed_ethnicity_checked(%{detailed: detailed_ethnicities}, detailed_ethnicity),
    do: detailed_ethnicity in detailed_ethnicities

  def detailed_ethnicity_checked(_, _),
    do: false

  def gender_identity_is_checked(),
    do: nil

  defp expected_person_params_from_changeset(changeset),
    do: changeset |> Extra.Changeset.get_field_from_changeset(:ethnicity)
end
