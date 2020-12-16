defmodule EpicenterWeb.Features.ContactInvestigationTest do
  use EpicenterWeb.ConnCase, async: true

  alias Epicenter.Cases
  alias Epicenter.Test
  alias EpicenterWeb.Test.Pages

  setup :register_and_log_in_user

  setup %{user: user} do
    sick_person =
      Test.Fixtures.person_attrs(user, "alice")
      |> Cases.create_person!()

    lab_result =
      Test.Fixtures.lab_result_attrs(sick_person, user, "lab_result", ~D[2020-08-07])
      |> Cases.create_lab_result!()

    case_investigation =
      Test.Fixtures.case_investigation_attrs(sick_person, lab_result, user, "the contagious person's case investigation")
      |> Cases.create_case_investigation!()

    {:ok, contact_investigation} =
      {Test.Fixtures.contact_investigation_attrs("contact_investigation", %{exposing_case_id: case_investigation.id}),
       Test.Fixtures.admin_audit_meta()}
      |> Cases.create_contact_investigation()

    exposed_person = Cases.get_person(contact_investigation.exposed_person_id)
    [contact_investigation: contact_investigation, exposed_person: exposed_person]
  end

  test "user can discontinue a contact investigation", %{conn: conn, contact_investigation: contact_investigation, exposed_person: exposed_person} do
    view =
      conn
      |> Pages.Profile.visit(exposed_person)
      |> Pages.Profile.assert_here(exposed_person)

    assert [%{status: "Pending"}] = Pages.Profile.contact_investigations(view)

    contact_investigations =
      view
      |> Pages.Profile.click_discontinue_contact_investigation(contact_investigation.tid)
      |> Pages.follow_live_view_redirect(conn)
      |> Pages.ContactInvestigationDiscontinue.assert_here(contact_investigation)
      |> Pages.submit_and_follow_redirect(conn, "#contact-investigation-discontinue-form",
        contact_investigation: %{"interview_discontinue_reason" => "Unable to reach"}
      )
      |> Pages.Profile.assert_here(contact_investigation.exposed_person)
      |> Pages.Profile.contact_investigations()

    assert [%{status: "Discontinued"}] = contact_investigations
  end

  test "user can conduct a contact investigation", %{conn: conn, contact_investigation: contact_investigation, exposed_person: exposed_person} do
    view =
      conn
      |> Pages.Profile.visit(exposed_person)
      |> Pages.Profile.assert_here(exposed_person)

    assert [%{status: "Pending"}] = Pages.Profile.contact_investigations(view)

    view =
      view
      |> Pages.Profile.click_start_contact_investigation(contact_investigation.tid)
      |> Pages.follow_live_view_redirect(conn)
      |> Pages.ContactInvestigationStartInterview.assert_here()
      |> Pages.submit_and_follow_redirect(conn, "#contact-investigation-interview-start-form",
        start_interview_form: %{
          "person_interviewed" => "Alice's guardian",
          "date_started" => "09/06/2020",
          "time_started" => "03:45",
          "time_started_am_pm" => "PM"
        }
      )
      |> Pages.Profile.assert_here(contact_investigation.exposed_person)

    assert [
             %{
               interview_buttons: ["Discontinue"],
               interview_history_items: ["Started interview with proxy Alice's guardian on 09/06/2020 at 03:45pm EDT"],
               status: "Ongoing"
             }
           ] = Pages.Profile.contact_investigations(view)

    view
    |> Pages.Profile.click_edit_contact_clinical_details_link(contact_investigation.tid)
    |> Pages.follow_live_view_redirect(conn)
    |> Pages.ContactInvestigationClinicalDetails.assert_here()
  end
end
