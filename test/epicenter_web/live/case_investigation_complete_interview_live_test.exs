defmodule EpicenterWeb.CaseInvestigationCompleteInterviewLiveTest do
  use EpicenterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Epicenter.Cases
  alias Epicenter.Test
  alias EpicenterWeb.Test.Pages

  setup :register_and_log_in_user

  setup %{user: user} do
    person = Test.Fixtures.person_attrs(user, "alice") |> Cases.create_person!()
    lab_result = Test.Fixtures.lab_result_attrs(person, user, "lab_result", ~D[2020-10-27]) |> Cases.create_lab_result!()
    case_investigation = Test.Fixtures.case_investigation_attrs(person, lab_result, user, "investigation") |> Cases.create_case_investigation!()
    [case_investigation: case_investigation, person: person, user: user]
  end

  test "shows complete case investigation form", %{conn: conn, case_investigation: case_investigation} do
    Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
    |> Pages.CaseInvestigationCompleteInterview.assert_here()
    |> Pages.CaseInvestigationCompleteInterview.assert_date_completed(:today)
    |> Pages.CaseInvestigationCompleteInterview.assert_time_completed(:now)
  end

  test "prefills with existing data when existing data is available and can be edited", %{conn: conn, case_investigation: case_investigation} do
    {:ok, _} =
      Cases.update_case_investigation(
        case_investigation,
        {%{completed_interview_at: ~N[2020-01-01 23:03:07]}, Test.Fixtures.admin_audit_meta()}
      )

    Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
    |> Pages.CaseInvestigationCompleteInterview.assert_here()
    |> Pages.CaseInvestigationCompleteInterview.assert_time_completed("06:03", "PM")
    |> Pages.CaseInvestigationCompleteInterview.assert_date_completed("01/01/2020")
    |> Pages.submit_and_follow_redirect(conn, "#case-investigation-interview-complete-form",
      complete_interview_form: %{
        "date_completed" => "09/06/2020",
        "time_completed" => "03:45",
        "time_completed_am_pm" => "PM"
      }
    )

    case_investigation = Cases.get_case_investigation(case_investigation.id)
    assert Timex.to_datetime({{2020, 9, 6}, {19, 45, 0}}, "UTC") == case_investigation.completed_interview_at
  end

  test "saving complete case investigation", %{conn: conn, case_investigation: case_investigation, person: person} do
    Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
    |> Pages.submit_and_follow_redirect(conn, "#case-investigation-interview-complete-form",
      complete_interview_form: %{
        "date_completed" => "09/06/2020",
        "time_completed" => "03:45",
        "time_completed_am_pm" => "PM"
      }
    )
    |> Pages.Profile.assert_here(person)

    # TODO show history text on profile
    #    |> Pages.Profile.assert_case_investigation_has_history("Completed interview on 09/06/2020 at 03:45pm EDT")

    case_investigation = Cases.get_case_investigation(case_investigation.id)
    assert Timex.to_datetime({{2020, 9, 6}, {19, 45, 0}}, "UTC") == case_investigation.completed_interview_at
  end

  describe "warning the user when navigation will erase their changes" do
    test "before the user changes anything", %{conn: conn, case_investigation: case_investigation} do
      Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
      |> Pages.assert_confirmation_prompt("")
    end

    test "when the user changes something", %{conn: conn, case_investigation: case_investigation} do
      Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
      |> Pages.CaseInvestigationCompleteInterview.change_form(%{"date_completed" => "09/06/2020"})
      |> Pages.assert_confirmation_prompt("Your updates have not been saved. Discard updates?")
    end
  end

  describe "validation" do
    test "invalid times become errors", %{conn: conn, case_investigation: case_investigation} do
      view =
        Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
        |> Pages.submit_live("#case-investigation-interview-complete-form",
          complete_interview_form: %{
            "date_completed" => "09/06/2020",
            "time_completed" => "13:45",
            "time_completed_am_pm" => "PM"
          }
        )

      view |> render() |> assert_validation_messages(%{"complete_interview_form_time_completed" => "is invalid"})
    end

    test "invalid dates become errors", %{conn: conn, case_investigation: case_investigation} do
      view =
        Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
        |> Pages.submit_live("#case-investigation-interview-complete-form",
          complete_interview_form: %{
            "date_completed" => "09/32/2020",
            "time_completed" => "12:45",
            "time_completed_am_pm" => "PM"
          }
        )

      view |> render() |> assert_validation_messages(%{"complete_interview_form_date_completed" => "is invalid"})
    end

    test "daylight savings hour that doesn't exist becomes an error", %{conn: conn, case_investigation: case_investigation} do
      view =
        Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
        |> Pages.submit_live("#case-investigation-interview-complete-form",
          complete_interview_form: %{
            "date_completed" => "03/08/2020",
            "time_completed" => "02:10",
            "time_completed_am_pm" => "AM"
          }
        )

      view |> render() |> assert_validation_messages(%{"complete_interview_form_time_completed" => "is invalid"})
    end

    test "validates presence of all fields", %{conn: conn, case_investigation: case_investigation} do
      view =
        Pages.CaseInvestigationCompleteInterview.visit(conn, case_investigation)
        |> Pages.submit_live("#case-investigation-interview-complete-form",
          complete_interview_form: %{
            "date_completed" => "",
            "time_completed" => "",
            "time_completed_am_pm" => "AM"
          }
        )

      view
      |> render()
      |> assert_validation_messages(%{
        "complete_interview_form_date_completed" => "can't be blank",
        "complete_interview_form_time_completed" => "can't be blank"
      })
    end
  end
end