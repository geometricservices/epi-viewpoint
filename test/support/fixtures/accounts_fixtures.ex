defmodule Epicenter.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Epicenter.Accounts` context.
  """

  alias Epicenter.Accounts
  alias Epicenter.Repo
  alias Epicenter.Test

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "password123"

  def user_fixture(attrs \\ %{tid: "user"}) do
    attrs |> unconfirmed_user_fixture() |> confirm_user() |> set_mfa()
  end

  def single_factor_user_fixture(attrs \\ %{tid: "single-factor"}) do
    attrs |> unconfirmed_user_fixture() |> confirm_user()
  end

  def unconfirmed_user_fixture(attrs \\ %{tid: "unconfirmed"}) do
    Test.Fixtures.user_attrs(Test.Fixtures.admin(), attrs) |> Accounts.register_user!()
  end

  defp confirm_user(user) do
    user |> Accounts.User.confirm_changeset() |> Repo.update!()
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.body, "[TOKEN]")
    token
  end

  defp set_mfa(user) do
    user |> Accounts.update_user_mfa!({Epicenter.Test.TOTPStub.encoded_secret(), Epicenter.Test.Fixtures.audit_meta(user)})
  end
end
