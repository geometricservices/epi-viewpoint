defmodule Epicenter.Cases do
  alias Epicenter.Cases.Assignment
  alias Epicenter.Cases.Import
  alias Epicenter.Cases.LabResult
  alias Epicenter.Cases.Person
  alias Epicenter.Cases.Phone
  alias Epicenter.Repo

  #
  # assignments
  #
  def preload_assignments(user_or_users_or_nil), do: user_or_users_or_nil |> Repo.preload([:assignments])
  def change_assignment(%Assignment{} = assignment, attrs), do: Assignment.changeset(assignment, attrs)

  def create_assignments!(user, people),
    do: people |> Enum.map(fn person -> change_assignment(%Assignment{}, %{person_id: person.id, user_id: user.id}) |> Repo.insert!() end)

  #
  # lab results
  #
  def change_lab_result(%LabResult{} = lab_result, attrs), do: LabResult.changeset(lab_result, attrs)
  def count_lab_results(), do: LabResult |> Repo.aggregate(:count)
  def create_lab_result!(attrs), do: %LabResult{} |> change_lab_result(attrs) |> Repo.insert!()
  def import_lab_results(lab_result_csv_string, originator), do: Import.from_csv(lab_result_csv_string, originator)
  def list_lab_results(), do: LabResult.Query.all() |> Repo.all()
  def preload_lab_results(person_or_people_or_nil), do: person_or_people_or_nil |> Repo.preload([:lab_results])

  #
  # people
  #
  def change_person(%Person{} = person, attrs), do: Person.changeset(person, attrs)
  def count_people(), do: Person |> Repo.aggregate(:count)
  def create_person(attrs), do: %Person{} |> change_person(attrs) |> Repo.Versioned.insert()
  def create_person!(attrs), do: %Person{} |> change_person(attrs) |> Repo.Versioned.insert!()
  def get_person(id), do: Person |> Repo.get(id)
  def list_people(), do: list_people(:all)
  def list_people(:all), do: Person.Query.all() |> Repo.all()
  def list_people(:with_lab_results), do: Person.Query.with_lab_results() |> Repo.all()
  def list_people(:call_list), do: Person.Query.call_list() |> Repo.all()
  def update_person(%Person{} = person, attrs), do: person |> change_person(attrs) |> Repo.Versioned.update()
  def upsert_person!(attrs), do: %Person{} |> change_person(attrs) |> Repo.Versioned.insert!(ecto_options: Person.Query.opts_for_upsert())

  #
  # phone
  #
  def change_phone(%Phone{} = phone, attrs), do: Phone.changeset(phone, attrs)
  def count_phones(), do: Phone |> Repo.aggregate(:count)
  def create_phone(attrs), do: %Phone{} |> change_phone(attrs) |> Repo.insert()
  def create_phone!(attrs), do: %Phone{} |> change_phone(attrs) |> Repo.insert!()
  def preload_phones(person_or_people_or_nil), do: person_or_people_or_nil |> Repo.preload([:phones])

  #
  # pubsub
  #
  def broadcast(message), do: Phoenix.PubSub.broadcast(Epicenter.PubSub, "cases", message)
  def subscribe(), do: Phoenix.PubSub.subscribe(Epicenter.PubSub, "cases")
end
