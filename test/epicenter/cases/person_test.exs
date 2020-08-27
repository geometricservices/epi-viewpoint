defmodule Epicenter.Cases.PersonTest do
  use Epicenter.DataCase, async: true

  import Euclid.Extra.Enum, only: [tids: 1]

  alias Epicenter.Accounts
  alias Epicenter.Cases
  alias Epicenter.Cases.Person
  alias Epicenter.Test

  describe "schema" do
    test "fields" do
      assert_schema(
        Person,
        [
          {:dob, :date},
          {:fingerprint, :string},
          {:first_name, :string},
          {:id, :id},
          {:inserted_at, :naive_datetime},
          {:last_name, :string},
          {:seq, :integer},
          {:tid, :string},
          {:updated_at, :naive_datetime}
        ]
      )
    end
  end

  describe "associations" do
    test "can have zero lab_results" do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      alice = Test.Fixtures.person_attrs(user, "alice", "01-01-2000") |> Cases.create_person!()
      alice |> Cases.preload_lab_results() |> Map.get(:lab_results) |> assert_eq([])
    end

    test "has many lab_results" do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      alice = Test.Fixtures.person_attrs(user, "alice", "01-01-2000") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(alice, "result1", "06-01-2020") |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, "result2", "06-02-2020") |> Cases.create_lab_result!()

      alice
      |> Cases.preload_lab_results()
      |> Map.get(:lab_results)
      |> tids()
      |> assert_eq(~w{result1 result2}, ignore_order: true)
    end
  end

  describe "changeset" do
    defp new_changeset(attr_updates) do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      default_attrs = Test.Fixtures.person_attrs(user, "alice", "01-01-2000")
      Cases.change_person(%Person{}, Map.merge(default_attrs, attr_updates |> Enum.into(%{})))
    end

    test "default test attrs are valid", do: assert_valid(new_changeset(%{}))
    test "dob is required", do: assert_invalid(new_changeset(dob: nil))
    test "first name is required", do: assert_invalid(new_changeset(first_name: nil))
    test "last name is required", do: assert_invalid(new_changeset(last_name: nil))
    test "originator is required", do: assert_invalid(new_changeset(originator: nil))

    test "generates a fingerprint", do: assert(new_changeset(%{}).changes.fingerprint == "2000-01-01 alice aliceblat")
    test "has originator virtual field", do: assert(new_changeset(%{}).changes.originator.tid == "user")
  end

  describe "constraints" do
    defp fingerprint_contstraint_error?(attrs) do
      case Cases.create_person(attrs) do
        {:ok, %Person{}} ->
          false

        {:error, changeset} ->
          if errors_on(changeset).fingerprint == ["has already been taken"],
            do: true,
            else: raise("Unexpected changeset errors: #{changeset |> errors_on() |> inspect()}")
      end
    end

    test "case-insensitive unique constraint on first_name + last_name + dob" do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      alice_attrs = Test.Fixtures.person_attrs(user, "alice", "01-01-2000")
      assert {:ok, %Person{} = _} = alice_attrs |> Cases.create_person()

      assert fingerprint_contstraint_error?(alice_attrs)

      assert fingerprint_contstraint_error?(alice_attrs |> Map.put(:first_name, "ALICE"))
      assert fingerprint_contstraint_error?(alice_attrs |> Map.put(:first_name, "aLiCe"))
      refute fingerprint_contstraint_error?(alice_attrs |> Map.put(:first_name, "Alice2"))

      assert fingerprint_contstraint_error?(alice_attrs |> Map.put(:last_name, "ALICEBLAT"))
      assert fingerprint_contstraint_error?(alice_attrs |> Map.put(:last_name, "AlIcEbLaT"))
      refute fingerprint_contstraint_error?(alice_attrs |> Map.put(:last_name, "Aliceblat2"))

      refute fingerprint_contstraint_error?(alice_attrs |> Map.put(:dob, ~D[1999-09-09]))
    end
  end

  describe "latest_lab_result" do
    test "returns nil if no lab results" do
      Test.Fixtures.user_attrs("user")
      |> Accounts.create_user!()
      |> Test.Fixtures.person_attrs("alice", "01-01-2000")
      |> Cases.create_person!()
      |> Person.latest_lab_result()
      |> assert_eq(nil)
    end

    test "returns the lab result with the most recent sample date" do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      alice = Test.Fixtures.person_attrs(user, "alice", "01-01-2000") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(alice, "newer", "06-02-2020") |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, "older", "06-01-2020") |> Cases.create_lab_result!()

      assert Person.latest_lab_result(alice).tid == "newer"
    end

    test "when given a field, returns the value of that field for the latest lab result" do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      alice = Test.Fixtures.person_attrs(user, "alice", "01-01-2000") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(alice, "earlier-result", "06-01-2020", result: "negative") |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, "later-result", "06-02-2020", result: "positive") |> Cases.create_lab_result!()

      assert Person.latest_lab_result(alice, :result) == "positive"
      assert Person.latest_lab_result(alice, :sample_date) == ~D[2020-06-02]
    end

    test "when given a field but there is no lab result, returns nil" do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      alice = Test.Fixtures.person_attrs(user, "alice", "01-01-2000") |> Cases.create_person!()
      assert Person.latest_lab_result(alice, :result) == nil
      assert Person.latest_lab_result(alice, :sample_date) == nil
    end
  end
end
