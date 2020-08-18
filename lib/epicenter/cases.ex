defmodule Epicenter.Cases do
  alias Epicenter.Cases.Case
  alias Epicenter.Cases.Import
  alias Epicenter.Cases.LabResult
  alias Epicenter.Cases.Person
  alias Epicenter.Repo

  #
  # cases
  #
  def list_cases(), do: list_people() |> Case.new()

  #
  # lab results
  #
  def change_lab_result(%LabResult{} = lab_result, attrs), do: LabResult.changeset(lab_result, attrs)
  def create_lab_result!(attrs), do: %LabResult{} |> change_lab_result(attrs) |> Repo.insert!()
  def import_lab_results(lab_result_csv_string), do: Import.from_csv(lab_result_csv_string)
  def list_lab_results(), do: LabResult.Query.all() |> Repo.all()

  #
  # people
  #
  def change_person(%Person{} = person, attrs), do: Person.changeset(person, attrs)
  def create_person(attrs), do: %Person{} |> change_person(attrs) |> Repo.insert()
  def create_person!(attrs), do: %Person{} |> change_person(attrs) |> Repo.insert!()
  def list_people(), do: Person.Query.all() |> Repo.all()
  def preload_lab_results(person_or_people_or_nil), do: person_or_people_or_nil |> Repo.preload([:lab_results])
  def upsert_person!(attrs), do: %Person{} |> change_person(attrs) |> Repo.insert!(Person.Query.opts_for_upsert())
end
