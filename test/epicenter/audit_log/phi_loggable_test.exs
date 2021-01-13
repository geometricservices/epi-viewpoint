defmodule Epicenter.AuditLog.PhiLoggableTest do
  use Epicenter.DataCase, async: true

  alias Epicenter.AuditLog.PhiLoggable
  alias Epicenter.Cases
  alias Epicenter.ContactInvestigations
  alias Epicenter.Test

  setup :persist_admin
  @admin Test.Fixtures.admin()

  describe "ContactInvestigation" do
    setup do
      person = Test.Fixtures.person_attrs(@admin, "alice") |> Cases.create_person!()
      lab_result = Test.Fixtures.lab_result_attrs(person, @admin, "lab_result", ~D[2020-10-27]) |> Cases.create_lab_result!()

      case_investigation =
        Test.Fixtures.case_investigation_attrs(person, lab_result, @admin, "investigation", %{})
        |> Cases.create_case_investigation!()

      {:ok, contact_investigation} =
        Test.Fixtures.contact_investigation_attrs("contact-investigation-tid", %{
          exposing_case_id: case_investigation.id,
          exposed_person_id: Ecto.UUID.generate()
        })
        |> Test.Fixtures.wrap_with_audit_meta()
        |> ContactInvestigations.create()

      [contact_investigation: contact_investigation]
    end

    test "returns the exposed_person_id", %{contact_investigation: contact_investigation} do
      assert PhiLoggable.phi_identifier(contact_investigation) == contact_investigation.exposed_person_id
    end
  end

  describe "CaseInvestigation" do
    setup do
      person = Test.Fixtures.person_attrs(@admin, "alice") |> Cases.create_person!()
      lab_result = Test.Fixtures.lab_result_attrs(person, @admin, "lab_result", ~D[2020-10-27]) |> Cases.create_lab_result!()

      case_investigation =
        Test.Fixtures.case_investigation_attrs(person, lab_result, @admin, "investigation", %{})
        |> Cases.create_case_investigation!()

      [case_investigation: case_investigation]
    end

    test "returns the person_id", %{case_investigation: case_investigation} do
      assert PhiLoggable.phi_identifier(case_investigation) == case_investigation.person_id
    end
  end
end
