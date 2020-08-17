defmodule Epicenter.Test.Fixtures do
  alias Epicenter.DateParser

  def lab_result_attrs(tid, sample_date, attrs \\ %{}) do
    %{
      request_accession_number: "accession-" <> tid,
      request_facility_code: "facility-" <> tid,
      request_facility_name: tid <> " Lab, Inc.",
      result: "positive",
      sample_date: sample_date |> DateParser.parse_mm_dd_yyyy!(),
      tid: tid
    }
    |> merge_attrs(attrs)
  end

  def person_attrs(tid, dob, attrs \\ %{}) do
    %{
      dob: dob |> DateParser.parse_mm_dd_yyyy!(),
      first_name: String.capitalize(tid),
      last_name: String.capitalize(tid <> "blat"),
      tid: tid
    }
    |> merge_attrs(attrs)
  end

  defp merge_attrs(defaults, attrs) do
    Map.merge(defaults, Enum.into(attrs, %{}))
  end
end