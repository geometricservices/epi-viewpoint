defmodule Epicenter.Cases.PersonTest do
  use Epicenter.DataCase, async: true

  import Euclid.Extra.Enum, only: [tids: 1]

  alias Epicenter.Accounts
  alias Epicenter.Cases
  alias Epicenter.Extra
  alias Epicenter.Cases.Person
  alias Epicenter.Test

  @admin Test.Fixtures.admin()

  describe "schema" do
    test "fields" do
      assert_schema(
        Person,
        [
          {:assigned_to_id, :binary_id},
          {:dob, :date},
          {:employment, :string},
          {:ethnicity, :map},
          {:external_id, :string},
          {:fingerprint, :string},
          {:first_name, :string},
          {:gender_identity, :string},
          {:id, :id},
          {:inserted_at, :naive_datetime},
          {:last_name, :string},
          {:marital_status, :string},
          {:notes, :text},
          {:occupation, :string},
          {:preferred_language, :string},
          {:race, :string},
          {:seq, :integer},
          {:sex_at_birth, :string},
          {:tid, :string},
          {:updated_at, :naive_datetime}
        ]
      )
    end
  end

  describe "associations" do
    test "can have zero lab_results" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      alice |> Cases.preload_lab_results() |> Map.get(:lab_results) |> assert_eq([])
    end

    test "has many lab_results" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(alice, user, "result1", "06-01-2020") |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, user, "result2", "06-02-2020") |> Cases.create_lab_result!()

      alice
      |> Cases.preload_lab_results()
      |> Map.get(:lab_results)
      |> tids()
      |> assert_eq(~w{result1 result2}, ignore_order: true)
    end

    test "has many phone numbers" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      Test.Fixtures.phone_attrs(user, alice, "phone-1", number: "111-111-1000") |> Cases.create_phone!()
      Test.Fixtures.phone_attrs(user, alice, "phone-2", number: "111-111-1001") |> Cases.create_phone!()

      assert alice |> Cases.preload_phones() |> Map.get(:phones) |> tids() == ~w{phone-1 phone-2}
    end

    test "has many email addresses" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      Test.Fixtures.email_attrs(user, alice, "email-1") |> Cases.create_email!()
      Test.Fixtures.email_attrs(user, alice, "email-2") |> Cases.create_email!()

      assert alice |> Cases.preload_emails() |> Map.get(:emails) |> tids() == ~w{email-1 email-2}
    end
  end

  describe "changeset" do
    defp new_changeset(attr_updates) do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      default_attrs = Test.Fixtures.raw_person_attrs(user, "alice") |> Test.Fixtures.add_demographic_attrs()
      Person.changeset(%Person{}, Map.merge(default_attrs, attr_updates |> Enum.into(%{})))
    end

    test "assignment_changeset can assign or unassign a user to a person" do
      creator = Test.Fixtures.user_attrs(@admin, "creator") |> Accounts.register_user!()
      assigned_to = Test.Fixtures.user_attrs(@admin, "assigned-to") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(creator, "alice") |> Cases.create_person!()

      changeset = Person.assignment_changeset(alice, assigned_to)
      assert changeset.changes.assigned_to_id == assigned_to.id

      changeset = Person.assignment_changeset(changeset, nil)
      assert changeset.changes.assigned_to_id == nil
    end

    test "identifying attributes" do
      changes = new_changeset(%{external_id: "10000"}).changes
      assert changes.dob == ~D[2000-01-01]
      assert changes.external_id == "10000"
      assert changes.fingerprint == "2000-01-01 alice testuser"
      assert changes.first_name == "Alice"
      assert changes.last_name == "Testuser"
      assert changes.preferred_language == "English"
      assert changes.tid == "alice"
    end

    test "demographic attributes" do
      changes = new_changeset(%{ethnicity: %{parent: "hispanic", children: ["cuban", "puerto_rican"]}}).changes
      assert changes.employment == "Part time"
      assert changes.gender_identity == "Female"
      assert changes.marital_status == "Single"
      assert changes.notes == "lorem ipsum"
      assert changes.occupation == "architect"
      assert changes.race == "Filipino"
      assert changes.sex_at_birth == "Female"

      ethnicity_changes = changes.ethnicity.changes
      assert ethnicity_changes.parent == "hispanic"
      assert ethnicity_changes.children == ["cuban", "puerto_rican"]
    end

    test "default test attrs are valid", do: assert_valid(new_changeset(%{}))
    test "dob is required", do: assert_invalid(new_changeset(dob: nil))
    test "first name is required", do: assert_invalid(new_changeset(first_name: nil))
    test "last name is required", do: assert_invalid(new_changeset(last_name: nil))
    test "validates personal health information on dob", do: assert_invalid(new_changeset(dob: "01-10-2000"))
    test "validates personal health information on last_name", do: assert_invalid(new_changeset(last_name: "Aliceblat"))

    test "generates a fingerprint", do: assert(new_changeset(%{}).changes.fingerprint == "2000-01-01 alice testuser")
  end

  describe "constraints" do
    defp fingerprint_contstraint_error?({attrs, audit_meta}, key, new_value) do
      {attrs |> Map.put(key, new_value), audit_meta}
      |> fingerprint_contstraint_error?()
    end

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
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice_attrs = Test.Fixtures.person_attrs(user, "alice")
      assert {:ok, %Person{} = _} = alice_attrs |> Cases.create_person()

      assert fingerprint_contstraint_error?(alice_attrs)

      assert fingerprint_contstraint_error?(alice_attrs, :first_name, "ALICE")
      assert fingerprint_contstraint_error?(alice_attrs, :first_name, "aLiCe")
      refute fingerprint_contstraint_error?(alice_attrs, :first_name, "Alice2")
      refute fingerprint_contstraint_error?(alice_attrs, :dob, ~D[1999-09-01])
    end
  end

  describe "latest_lab_result" do
    test "returns nil if no lab results" do
      Test.Fixtures.user_attrs(@admin, "user")
      |> Accounts.register_user!()
      |> Test.Fixtures.person_attrs("alice")
      |> Cases.create_person!()
      |> Person.latest_lab_result()
      |> assert_eq(nil)
    end

    test "returns the lab result with the most recent sample date" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(alice, user, "newer", "06-02-2020") |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, user, "older", "06-01-2020") |> Cases.create_lab_result!()

      assert Person.latest_lab_result(alice).tid == "newer"
    end

    test "when there is a null sampled_on, returns that record first" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(alice, user, "newer", "06-02-2020") |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, user, "older", "06-01-2020") |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, user, "unknown", nil) |> Cases.create_lab_result!()

      assert Person.latest_lab_result(alice).tid == "unknown"
    end

    test "when there are two records with null sampled_on, returns the lab results with the largest seq" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      alice = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(alice, user, "unknown", nil) |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(alice, user, "newer unknown", nil) |> Cases.create_lab_result!()

      assert Person.latest_lab_result(alice).tid == "newer unknown"
    end
  end

  # # # Query

  describe "all" do
    test "sorts by last name (then first name, then dob descending)" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      Test.Fixtures.person_attrs(user, "middle", dob: ~D{2000-06-01}, first_name: "Alice", last_name: "Testuser") |> Cases.create_person!()
      Test.Fixtures.person_attrs(user, "last", dob: ~D{2000-06-01}, first_name: "Billy", last_name: "Testuser") |> Cases.create_person!()
      Test.Fixtures.person_attrs(user, "first", dob: ~D{2000-07-01}, first_name: "Alice", last_name: "Testuser") |> Cases.create_person!()

      Person.Query.all() |> Epicenter.Repo.all() |> tids() |> assert_eq(~w{first middle last})
    end
  end

  describe "call_list" do
    test "sorts by recent positive lab results" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()
      Test.Fixtures.person_attrs(user, "no-results") |> Cases.create_person!()

      Test.Fixtures.person_attrs(user, "old-positive-result")
      |> Cases.create_person!()
      |> Test.Fixtures.lab_result_attrs(user, "old-positive-result", Extra.Date.days_ago(20), result: "positive")
      |> Cases.create_lab_result!()

      Test.Fixtures.person_attrs(user, "recent-negative-result")
      |> Cases.create_person!()
      |> Test.Fixtures.lab_result_attrs(user, "recent-negative-result", Extra.Date.days_ago(1), result: "negative")
      |> Cases.create_lab_result!()

      Test.Fixtures.person_attrs(user, "recent-positive-result")
      |> Cases.create_person!()
      |> Test.Fixtures.lab_result_attrs(user, "recent-positive-result", Extra.Date.days_ago(1), result: "positive")
      |> Cases.create_lab_result!()

      Person.Query.call_list() |> Epicenter.Repo.all() |> tids() |> assert_eq(~w{recent-positive-result})
    end
  end

  describe "with_lab_results" do
    test "sorts by lab result sample date ascending" do
      user = Test.Fixtures.user_attrs(@admin, "user") |> Accounts.register_user!()

      middle = Test.Fixtures.person_attrs(user, "middle", dob: ~D[2000-06-01], first_name: "Middle", last_name: "Testuser") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(middle, user, "middle-1", ~D[2020-06-03]) |> Cases.create_lab_result!()

      last = Test.Fixtures.person_attrs(user, "last", dob: ~D[2000-06-01], first_name: "Last", last_name: "Testuser") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(last, user, "last-1", ~D[2020-06-04]) |> Cases.create_lab_result!()
      Test.Fixtures.lab_result_attrs(last, user, "last-1", ~D[2020-06-01]) |> Cases.create_lab_result!()

      first = Test.Fixtures.person_attrs(user, "first", dob: ~D[2000-06-01], first_name: "First", last_name: "Testuser") |> Cases.create_person!()
      Test.Fixtures.lab_result_attrs(first, user, "first-1", ~D[2020-06-02]) |> Cases.create_lab_result!()

      Person.Query.with_lab_results() |> Epicenter.Repo.all() |> tids() |> assert_eq(~w{first middle last})
    end

    test "includes people without lab results" do
      user =
        Test.Fixtures.user_attrs(@admin, "user")
        |> Accounts.register_user!()

      Test.Fixtures.person_attrs(user, "with-lab-result")
      |> Cases.create_person!()
      |> Test.Fixtures.lab_result_attrs(user, "lab-result", ~D[2020-06-02])
      |> Cases.create_lab_result!()

      Test.Fixtures.person_attrs(user, "without-lab-result")
      |> Cases.create_person!()

      Person.Query.with_lab_results()
      |> Epicenter.Repo.all()
      |> tids()
      |> assert_eq(~w{with-lab-result without-lab-result})
    end
  end

  describe "serializing for audit logs" do
    setup do
      person =
        Test.Fixtures.person_attrs(@admin, "old-positive-result")
        |> Cases.create_person!()

      person
      |> Test.Fixtures.lab_result_attrs(@admin, "old-positive-result", "09/18/2020", result: "positive")
      |> Cases.create_lab_result!()

      Test.Fixtures.email_attrs(@admin, person, "email")
      |> Cases.create_email!()

      Test.Fixtures.phone_attrs(@admin, person, "phone")
      |> Cases.create_phone!()

      person = Cases.get_person(person.id)
      [person: person]
    end

    test "with preloaded email/lab_result/phone", %{person: person} do
      person = person |> Cases.preload_phones() |> Cases.preload_emails() |> Cases.preload_lab_results()

      result = person |> Jason.encode!() |> Jason.decode!()

      person_id = person.id
      first_id = fn list -> Enum.at(list, 0).id end
      email_id = person.emails |> first_id.()
      phone_id = person.phones |> first_id.()
      lab_result_id = person.lab_results |> first_id.()

      assert %{
               "id" => ^person_id,
               "emails" => [
                 %{
                   "id" => ^email_id,
                   "address" => "email@example.com",
                   "delete" => nil,
                   "is_preferred" => nil,
                   "person_id" => ^person_id,
                   "tid" => "email"
                 }
               ],
               "lab_results" => [
                 %{
                   "id" => ^lab_result_id,
                   "person_id" => ^person_id,
                   "analyzed_on" => nil,
                   "reported_on" => nil,
                   "request_accession_number" => "accession-old-positive-result",
                   "request_facility_code" => "facility-old-positive-result",
                   "request_facility_name" => "old-positive-result Lab, Inc.",
                   "result" => "positive",
                   "sampled_on" => "2020-09-18",
                   "test_type" => nil,
                   "tid" => "old-positive-result"
                 }
               ],
               "phones" => [
                 %{
                   "id" => ^phone_id,
                   "number" => "1111111000",
                   "delete" => nil,
                   "is_preferred" => nil,
                   "person_id" => ^person_id,
                   "tid" => "phone",
                   "type" => "home"
                 }
               ]
             } = result
    end

    test "with nothing preloaded", %{person: person} do
      result_json = Jason.encode!(person)

      refute result_json =~ "emails"
      refute result_json =~ "lab_results"
      refute result_json =~ "phones"
    end
  end
end
