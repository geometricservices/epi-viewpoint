defmodule Epicenter.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Epicenter.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Epicenter.DataCase
      import Epicenter.Test.ChangesetAssertions
      import Epicenter.Test.SchemaAssertions
      import Epicenter.Test.RevisionAssertions
      import Euclid.Test.Extra.Assertions

      alias Epicenter.Repo
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Epicenter.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Epicenter.Repo, {:shared, self()})
    end

    Mox.stub_with(Epicenter.Test.PhiLoggerMock, Epicenter.Test.PhiLoggerStub)

    :ok
  end

  def persist_admin(_) do
    {:ok, _} = Epicenter.Test.Fixtures.admin() |> Epicenter.Accounts.change_user(%{}) |> Epicenter.Repo.insert()
    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.register_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
