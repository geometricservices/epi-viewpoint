defmodule Epicenter.Cases.Import do
  alias Epicenter.Accounts
  alias Epicenter.Cases
  alias Epicenter.Csv
  alias Epicenter.DateParser
  alias Epicenter.Repo

  @required_lab_result_fields ~w{datecollected_36 result_39 resultdate_42}
  @optional_lab_result_fields ~w{datereportedtolhd_44 lab_result_tid orderingfacilityname_37 testname_38}
  @required_person_fields ~w{dateofbirth_8 search_firstname_2 search_lastname_1}
  @optional_person_fields ~w{caseid_0 diagaddress_street1_3 diagaddress_city_4 diagaddress_state_5 diagaddress_zip_6 person_tid phonenumber_7}

  @fields [
    required: @required_lab_result_fields ++ @required_person_fields,
    optional: @optional_lab_result_fields ++ @optional_person_fields
  ]

  defmodule ImportInfo do
    defstruct ~w{imported_person_count imported_lab_result_count total_person_count total_lab_result_count}a
  end

  def import_csv(file, %Accounts.User{} = originator) do
    Repo.transaction(fn ->
      try do
        Cases.create_imported_file(file)

        Csv.read(file.contents, @fields)
        |> case do
          {:ok, rows} -> import_rows(rows, originator)
          {:error, message} -> Repo.rollback(message)
        end
      rescue
        error in NimbleCSV.ParseError ->
          Repo.rollback(error.message)

        error in Ecto.InvalidChangesetError ->
          Repo.rollback(error)
      end
    end)
  end

  defp import_rows(rows, originator) do
    result =
      for row <- rows, reduce: %{people: [], lab_results: []} do
        %{people: people, lab_results: lab_results} ->
          person =
            row
            |> Map.take(@required_person_fields ++ @optional_person_fields)
            |> Map.put("originator", originator)
            |> Euclid.Extra.Map.rename_keys(%{
              "caseid_0" => "external_id",
              "dateofbirth_8" => "dob",
              "person_tid" => "tid",
              "search_firstname_2" => "first_name",
              "search_lastname_1" => "last_name"
            })
            |> Euclid.Extra.Map.transform("dob", &DateParser.parse_mm_dd_yyyy!/1)
            |> Cases.upsert_person!()

          if Euclid.Exists.present?(Map.get(row, "phonenumber_7")) do
            Cases.upsert_phone!(%{number: Map.get(row, "phonenumber_7"), person_id: person.id})
          end

          [street, city, state, zip] =
            address_components =
            ~w{diagaddress_street1_3 diagaddress_city_4 diagaddress_state_5 diagaddress_zip_6}
            |> Enum.map(&Map.get(row, &1))

          if Euclid.Exists.any?(address_components) do
            Cases.upsert_address!(%{full_address: "#{street}, #{city}, #{state} #{zip}", person_id: person.id})
          end

          lab_result =
            row
            |> Map.take(@required_lab_result_fields ++ @optional_lab_result_fields)
            |> Map.put("person_id", person.id)
            |> Euclid.Extra.Map.rename_keys(%{
              "datecollected_36" => "sampled_on",
              "datereportedtolhd_44" => "reported_on",
              "lab_result_tid" => "tid",
              "orderingfacilityname_37" => "request_facility_name",
              "result_39" => "result",
              "resultdate_42" => "analyzed_on",
              "testname_38" => "test_type"
            })
            |> Euclid.Extra.Map.transform(["sampled_on", "reported_on", "analyzed_on"], &DateParser.parse_mm_dd_yyyy!/1)
            |> Cases.create_lab_result!()

          %{people: [person.id | people], lab_results: [lab_result.id | lab_results]}
      end

    import_info = %ImportInfo{
      imported_person_count: result.people |> Enum.uniq() |> length(),
      imported_lab_result_count: result.lab_results |> Enum.uniq() |> length(),
      total_person_count: Cases.count_people(),
      total_lab_result_count: Cases.count_lab_results()
    }

    Cases.broadcast({:import, import_info})

    import_info
  end
end
