defmodule EpicenterWeb.UserResetPasswordController do
  use EpicenterWeb, :controller

  alias Epicenter.Accounts
  alias EpicenterWeb.Session

  plug :get_user_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html", body_background: "color")
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    # Regardless of the outcome, show an impartial success/error message.
    message = "An email with instructions was sent"

    if user = Accounts.get_user_by_email(email) do
      {:ok, %{to: to, body: body}} =
        Accounts.deliver_user_reset_password_instructions(
          user,
          &Routes.user_reset_password_url(conn, :edit, &1)
        )

      conn
      |> Session.append_fake_mail(to, body)
      |> put_flash(:extra, "(Check your mail in /fakemail)")
    else
      conn
    end
    |> put_flash(:info, message)
    |> redirect(to: "/")
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: Accounts.change_user_password(conn.assigns.user))
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def update(conn, %{"user" => user_params}) do
    case Accounts.reset_user_password(conn.assigns.user, user_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.user_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user = Accounts.get_user_by_reset_password_token(token) do
      conn |> assign(:user, user) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
