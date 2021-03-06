defmodule EpicenterWeb.ImportControllerTest do
  use EpicenterWeb.ConnCase, async: true

  alias Epicenter.Accounts
  alias Epicenter.Cases.Import.ImportInfo
  alias Epicenter.Tempfile
  alias Epicenter.Test
  alias EpicenterWeb.Session

  setup :log_in_admin
  @admin Test.Fixtures.admin()

  describe "create" do
    test "prevents non-admins from uploading", %{conn: conn, user: user} do
      Accounts.update_user(user, %{admin: false}, Test.Fixtures.audit_meta(@admin))

      temp_file_path =
        """
        search_firstname_2 , search_lastname_1 , dateofbirth_8 , datecollected_36 , resultdate_42 , datereportedtolhd_44 , result_39 , glorp , person_tid
        Alice              , Testuser          , 01/01/1970    , 06/02/2020       , 06/01/2020    , 06/03/2020           , positive  , 393   , alice
        Billy              , Testuser          , 03/01/1990    , 06/05/2020       , 06/06/2020    , 06/07/2020           , negative  , sn3   , billy
        """
        |> Tempfile.write_csv!()

      on_exit(fn -> File.rm!(temp_file_path) end)

      conn = post(conn, Routes.import_path(conn, :create), %{"file" => %Plug.Upload{path: temp_file_path, filename: "test.csv"}})

      assert conn |> redirected_to() == "/"

      refute Session.get_last_csv_import_info(conn)
    end

    test "accepts file upload", %{conn: conn} do
      temp_file_path =
        """
        search_firstname_2 , search_lastname_1 , dateofbirth_8 , datecollected_36 , resultdate_42 , datereportedtolhd_44 , result_39 , glorp , person_tid
        Alice              , Testuser          , 01/01/1970    , 06/02/2020       , 06/01/2020    , 06/03/2020           , positive  , 393   , alice
        Billy              , Testuser          , 03/01/1990    , 06/05/2020       , 06/06/2020    , 06/07/2020           , negative  , sn3   , billy
        """
        |> Tempfile.write_csv!()

      on_exit(fn -> File.rm!(temp_file_path) end)

      conn = post(conn, Routes.import_path(conn, :create), %{"file" => %Plug.Upload{path: temp_file_path, filename: "test.csv"}})

      assert conn |> redirected_to() == "/import/complete"

      assert %Epicenter.Cases.Import.ImportInfo{
               imported_lab_result_count: 2,
               imported_person_count: 2,
               total_lab_result_count: 2,
               total_person_count: 2
             } = Session.get_last_csv_import_info(conn)
    end

    test "when a required column header is missing", %{conn: conn} do
      # remove the dob column
      temp_file_path =
        """
        search_firstname_2 , search_lastname_1 , datecollected_36 , resultdate_42 , datereportedtolhd_44 , result_39 , glorp , person_tid
        Alice              , Testuser          , 06/02/2020       , 06/01/2020    , 06/03/2020           , positive  , 393   , alice
        """
        |> Tempfile.write_csv!()

      on_exit(fn -> File.rm!(temp_file_path) end)

      conn = post(conn, Routes.import_path(conn, :create), %{"file" => %Plug.Upload{path: temp_file_path, filename: "test.csv"}})

      assert conn |> redirected_to() == "/import/start"
      assert "Missing required columns: dateofbirth_xx" = Session.get_import_error_message(conn)
    end

    test "when a date is poorly formatted", %{conn: conn} do
      # date collected has a bad year 06/02/bb
      temp_file_path =
        """
        search_firstname_2 , search_lastname_1 , dateofbirth_8 , datecollected_36 , resultdate_42 , datereportedtolhd_44 , result_39 , glorp , person_tid
        Alice              , Testuser          , 01/01/1970    , 06/02/bb         , 06/01/2020    , 06/03/2020           , positive  , 393   , alice
        """
        |> Tempfile.write_csv!()

      on_exit(fn -> File.rm!(temp_file_path) end)

      conn = post(conn, Routes.import_path(conn, :create), %{"file" => %Plug.Upload{path: temp_file_path, filename: "test.csv"}})

      assert conn |> redirected_to() == "/import/start"
      assert "Invalid mm-dd-yyyy format: 06/02/bb" = Session.get_import_error_message(conn)
    end
  end

  describe "show" do
    test "shows the number of items uploaded", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session([])
        |> Session.set_last_csv_import_info(%ImportInfo{
          imported_person_count: 2,
          imported_lab_result_count: 3,
          total_person_count: 50,
          total_lab_result_count: 100
        })
        |> get(Routes.import_path(conn, :show))

      assert conn |> html_response(200) =~ "Successfully imported 2 people and 3 lab results"
    end
  end
end
