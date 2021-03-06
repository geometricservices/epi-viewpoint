defmodule EpicenterWeb.ContactInvestigation do
  use EpicenterWeb, :live_component

  import EpicenterWeb.LiveComponent.Helpers
  import EpicenterWeb.Presenters.ContactInvestigationPresenter, only: [exposing_case_link: 1, history_items: 1, quarantine_history_items: 1]
  import EpicenterWeb.Presenters.InvestigationPresenter, only: [displayable_clinical_status: 1, displayable_symptoms: 1]
  import EpicenterWeb.Presenters.PeoplePresenter, only: [is_editable?: 1]

  alias Epicenter.ContactInvestigations.ContactInvestigation
  alias EpicenterWeb.Format
  alias EpicenterWeb.InvestigationNotesSection

  defp status_class(status) do
    case status do
      "completed" -> "completed-status"
      "discontinued" -> "discontinued-status"
      "started" -> "started-status"
      "ongoing" -> "started-status"
      _ -> "pending-status"
    end
  end

  defp status_text(%ContactInvestigation{} = %{interview_status: status}) do
    case status do
      "completed" -> "Completed"
      "discontinued" -> "Discontinued"
      "started" -> "Ongoing"
      _ -> "Pending"
    end
  end

  defp quarantine_monitoring_status_text(
         %{quarantine_monitoring_status: status, quarantine_monitoring_ends_on: quarantine_monitoring_ends_on},
         current_date
       ) do
    content_tag :h3, class: "contact-investigation-quarantine-monitoring-status", data_role: "contact-investigation-quarantine-monitoring-status" do
      case status do
        "ongoing" ->
          diff = Date.diff(quarantine_monitoring_ends_on, current_date)

          [
            content_tag(:span, "Ongoing", class: "started-status"),
            content_tag(:span, "quarantine monitoring (#{diff} days remaining)")
          ]

        "concluded" ->
          [
            content_tag(:span, "Concluded", class: "completed-status"),
            content_tag(:span, "quarantine monitoring")
          ]

        _ ->
          [
            content_tag(:span, "Pending", class: "pending-status"),
            content_tag(:span, "quarantine monitoring")
          ]
      end
    end
  end

  defp interview_buttons(contact_investigation) do
    case is_editable?(contact_investigation.exposed_person) do
      false ->
        []

      true ->
        case contact_investigation.interview_status do
          "pending" ->
            [
              redirect_to(contact_investigation, :start_interview),
              redirect_to(contact_investigation, :discontinue_interview)
            ]

          "started" ->
            [
              redirect_to(contact_investigation, :complete_interview),
              redirect_to(contact_investigation, :discontinue_interview)
            ]

          "completed" ->
            []

          "discontinued" ->
            []
        end
    end
  end

  defp redirect_to(contact_investigation, :complete_interview) do
    live_redirect("Complete interview",
      to:
        Routes.contact_investigation_complete_interview_path(
          EpicenterWeb.Endpoint,
          :complete_contact_investigation,
          contact_investigation
        ),
      class: "primary",
      data: [role: "contact-investigation-complete-interview-link"]
    )
  end

  defp redirect_to(contact_investigation, :discontinue_interview) do
    live_redirect("Discontinue",
      to:
        Routes.contact_investigation_discontinue_path(EpicenterWeb.Endpoint, EpicenterWeb.ContactInvestigationDiscontinueLive, contact_investigation),
      class: "discontinue-link",
      data: [role: "contact-investigation-discontinue-interview"]
    )
  end

  defp redirect_to(contact_investigation, :start_interview) do
    live_redirect("Start interview",
      to:
        Routes.contact_investigation_start_interview_path(
          EpicenterWeb.Endpoint,
          EpicenterWeb.ContactInvestigationStartInterviewLive,
          contact_investigation
        ),
      class: "primary",
      data: [role: "contact-investigation-start-interview"]
    )
  end

  def quarantine_monitoring_button(contact_investigation) do
    case is_editable?(contact_investigation.exposed_person) do
      false ->
        nil

      true ->
        case contact_investigation.quarantine_monitoring_status do
          "pending" ->
            live_redirect("Add quarantine dates",
              to:
                Routes.contact_investigation_quarantine_monitoring_path(
                  EpicenterWeb.Endpoint,
                  EpicenterWeb.ContactInvestigationQuarantineMonitoringLive,
                  contact_investigation
                ),
              class: "primary",
              data: [role: "contact-investigation-quarantine-monitoring-start-link"]
            )

          "ongoing" ->
            live_redirect("Conclude monitoring",
              to:
                Routes.contact_investigation_conclude_quarantine_monitoring_path(
                  EpicenterWeb.Endpoint,
                  EpicenterWeb.ContactInvestigationConcludeQuarantineMonitoringLive,
                  contact_investigation
                ),
              class: "primary",
              data: [role: "conclude-contact-investigation-quarantine-monitoring-link"]
            )

          "concluded" ->
            nil
        end
    end
  end
end
