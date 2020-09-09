defmodule Epicenter.Cases.PhoneTest do
  use Epicenter.DataCase, async: true

  alias Epicenter.Accounts
  alias Epicenter.Cases
  alias Epicenter.Cases.Phone
  alias Epicenter.Test

  describe "schema" do
    test "fields" do
      assert_schema(
        Cases.Phone,
        [
          {:id, :id},
          {:inserted_at, :naive_datetime},
          {:number, :integer},
          {:person_id, :id},
          {:seq, :integer},
          {:tid, :string},
          {:type, :string},
          {:updated_at, :naive_datetime}
        ]
      )
    end
  end

  describe "changeset" do
    defp new_changeset(attr_updates \\ %{}) do
      user = Test.Fixtures.user_attrs("user") |> Accounts.create_user!()
      person = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
      default_attrs = Test.Fixtures.phone_attrs(person, "phone")
      Phone.changeset(%Phone{}, Map.merge(default_attrs, attr_updates |> Enum.into(%{})))
    end

    test "attributes" do
      changes = new_changeset().changes
      assert changes.number == 1_111_111_000
      assert changes.type == "home"
      assert changes.tid == "phone"
    end

    test "default test attrs are valid", do: assert_valid(new_changeset(%{}))
    test "number is required", do: assert_invalid(new_changeset(number: nil))

    test "validates personal health information on number", do: assert_invalid(new_changeset(number: 2_111_111_000))
  end
end