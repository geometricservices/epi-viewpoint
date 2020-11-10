defmodule EpicenterWeb.Test.Pages.CaseInvestigationIsolationMonitoring do
  import ExUnit.Assertions
  import Phoenix.LiveViewTest

  alias Epicenter.Cases.CaseInvestigation
  alias Epicenter.Test
  alias EpicenterWeb.Test.Pages
  alias Phoenix.LiveViewTest.View

  def visit(%Plug.Conn{} = conn, %CaseInvestigation{id: case_investigation_id}) do
    conn |> Pages.visit("/case_investigations/#{case_investigation_id}/isolation_monitoring")
  end

  def assert_here(view_or_conn_or_html) do
    view_or_conn_or_html |> Pages.assert_on_page("case-investigation-isolation-monitoring")
  end

  def assert_isolation_date_started(%View{} = view, expected_date_string, expected_explanation_text) do
    assert view
           |> Pages.parse()
           |> Test.Html.find("input#isolation_monitoring_form_date_started")
           |> Test.Html.attr("value") == [expected_date_string]

    assert view
           |> Pages.parse()
           |> Test.Html.text(role: "onset-date") == expected_explanation_text

    view
  end

  def assert_isolation_date_ended(%View{} = view, expected_date_string) do
    assert view
           |> Pages.parse()
           |> Test.Html.find("input#isolation_monitoring_form_date_ended")
           |> Test.Html.attr("value") == [expected_date_string]

    view
  end

  def change_form(view, attrs, target \\ ["isolation_monitoring_form[date_started]"]) do
    view |> element("#case-investigation-isolation-monitoring-form") |> render_change(attrs |> Map.put(:_target, target))
    view
  end
end
