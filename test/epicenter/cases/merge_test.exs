defmodule Epicenter.Cases.MergeTest do
  use Epicenter.DataCase, async: true

  alias Epicenter.Accounts
  alias Epicenter.Cases
  alias Epicenter.Cases.Merge
  alias Epicenter.Test

  setup :persist_admin
  @admin Test.Fixtures.admin()

  defp create_person(user, tid, first_name, dob, preferred_language) do
    Test.Fixtures.person_attrs(
      user,
      tid,
      %{demographics: [%{first_name: first_name, dob: dob, preferred_language: preferred_language}]},
      demographics: true
    )
    |> Cases.create_person!()
  end

  defp create_people(people_attrs, user) do
    people_attrs
    |> Enum.map(fn {tid, first_name, dob, preferred_language} -> create_person(user, tid, first_name, dob, preferred_language) end)
    |> Enum.map(& &1.id)
  end

  setup do
    user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
    [user: user]
  end

  describe "merge_conflicts" do
    test "it identifies and returns the unique values for the 3 fields of interest", %{user: user} do
      people_attrs = [
        {"catie", "Catie", nil, "German"},
        {"catie2", "catie", ~D[2020-01-01], nil},
        {"katie", "Katie", ~D[2020-01-01], "German"},
        {"katie2", "Katie", ~D[1990-01-01], "English"},
        {"katy", "Katy", nil, "    "}
      ]

      person_ids = create_people(people_attrs, user)
      conflicts = Merge.merge_conflicts(person_ids, user, [{:first_name, :string}, {:dob, :date}, {:preferred_language, :string}])

      assert conflicts == %{
               first_name: ["Catie", "catie", "Katie", "Katy"],
               dob: [~D[1990-01-01], ~D[2020-01-01]],
               preferred_language: ["English", "German"]
             }
    end

    test "returns empty array for fields with no conflicts", %{user: user} do
      people_attrs = [
        {"catie", "Catie", nil, "German"},
        {"catie2", "Catie", nil, nil}
      ]

      person_ids = create_people(people_attrs, user)
      conflicts = Merge.merge_conflicts(person_ids, user, [{:first_name, :string}, {:dob, :date}, {:preferred_language, :string}])

      assert conflicts == %{
               first_name: [],
               dob: [],
               preferred_language: []
             }
    end
  end
end
