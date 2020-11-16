defmodule EpicenterWeb.Forms.DemographicForm do
  use Ecto.Schema

  import Ecto.Changeset

  alias Epicenter.Cases.Demographic
  alias Epicenter.Cases.Ethnicity
  alias Epicenter.Coerce
  alias Epicenter.MajorDetailed
  alias EpicenterWeb.Forms.DemographicForm

  @primary_key false

  embedded_schema do
    field :employment, :string

    field :ethnicity, :string
    field :ethnicity_hispanic_latinx_or_spanish_origin, {:array, :string}
    field :ethnicity_hispanic_latinx_or_spanish_origin_other, :string

    field :gender_identity, {:array, :string}
    field :gender_identity_other, :string

    field :marital_status, :string
    field :notes, :string
    field :occupation, :string

    field :race, {:array, :string}
    field :race_other, :string
    field :race_asian, {:array, :string}
    field :race_asian_other, :string
    field :race_native_hawaiian_or_other_pacific_islander, {:array, :string}
    field :race_native_hawaiian_or_other_pacific_islander_other, :string

    field :sex_at_birth, :string
  end

  @required_attrs ~w{}a
  @optional_attrs ~w{
    employment
    ethnicity
    ethnicity_hispanic_latinx_or_spanish_origin
    ethnicity_hispanic_latinx_or_spanish_origin_other
    gender_identity
    gender_identity_other
    marital_status
    notes
    occupation
    race
    race_other
    race_asian
    race_asian_other
    race_native_hawaiian_or_other_pacific_islander
    race_native_hawaiian_or_other_pacific_islander_other
    sex_at_birth
  }a

  def model_to_form_changeset(%Demographic{} = demographic) do
    demographic |> model_to_form_attrs() |> attrs_to_form_changeset()
  end

  def model_to_form_attrs(%Demographic{} = demographic) do
    {gender_identity, gender_identity_other} =
      (demographic.gender_identity || []) |> Enum.split_with(&(&1 in Demographic.standard_values(:gender_identity)))

    %{
      employment: demographic.employment,
      ethnicity: demographic.ethnicity |> Ethnicity.major(),
      ethnicity_hispanic_latinx_or_spanish_origin: demographic.ethnicity |> Ethnicity.hispanic_latinx_or_spanish_origin(),
      gender_identity: gender_identity,
      gender_identity_other: gender_identity_other,
      marital_status: demographic.marital_status,
      notes: demographic.notes,
      occupation: demographic.occupation,
      sex_at_birth: demographic.sex_at_birth
    }
    |> Map.merge(MajorDetailed.split(demographic, :race, Demographic.humanized_values(:race)))
  end

  def attrs_to_form_changeset(attrs) do
    attrs =
      attrs
      |> Euclid.Extra.Map.stringify_keys()
      |> Euclid.Extra.Map.transform(
        ~w{employment ethnicity ethnicity_hispanic_latinx_or_spanish_origin_other gender_identity_other marital_status sex_at_birth},
        &Coerce.to_string_or_nil/1
      )

    %DemographicForm{}
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end

  def form_changeset_to_model_attrs(%Ecto.Changeset{} = form_changeset) do
    case apply_action(form_changeset, :create) do
      {:ok, form} ->
        {:ok,
         %{
           employment: form.employment,
           ethnicity: extract_ethnicity(form),
           gender_identity: extract_gender_identity(form),
           marital_status: form.marital_status,
           notes: form.notes,
           occupation: form.occupation,
           race: extract_race(form),
           sex_at_birth: form.sex_at_birth,
           source: "form"
         }}

      other ->
        other
    end
  end

  defp extract_ethnicity(form) do
    major = form.ethnicity

    detailed =
      if major == "hispanic_latinx_or_spanish_origin" do
        [form.ethnicity_hispanic_latinx_or_spanish_origin, form.ethnicity_hispanic_latinx_or_spanish_origin_other]
        |> flat_compact()
      else
        nil
      end

    %{major: major, detailed: detailed}
  end

  defp extract_gender_identity(form) do
    [form.gender_identity, form.gender_identity_other] |> flat_compact()
  end

  defp extract_race(form) do
    form.race
    |> List.wrap()
    |> Enum.reduce(%{}, fn
      "asian", acc ->
        Map.put(acc, "asian", [form.race_asian, form.race_asian_other] |> flat_compact())

      "native_hawaiian_or_other_pacific_islander", acc ->
        Map.put(
          acc,
          "native_hawaiian_or_other_pacific_islander",
          [form.race_native_hawaiian_or_other_pacific_islander, form.race_native_hawaiian_or_other_pacific_islander_other] |> flat_compact()
        )

      race, acc ->
        Map.put(acc, race, nil)
    end)
    |> (fn extracted ->
          if Euclid.Exists.present?(form.race_other),
            do: Map.put(extracted, form.race_other, nil),
            else: extracted
        end).()
  end

  defp flat_compact(list) do
    list |> List.flatten() |> Enum.filter(&Euclid.Exists.present?/1) |> Enum.sort()
  end
end
