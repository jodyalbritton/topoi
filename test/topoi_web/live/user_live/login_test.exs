defmodule TopoiWeb.UserLive.LoginTest do
  use TopoiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures

  describe "login page" do
    test "renders a username + password form only", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      assert has_element?(lv, ~s(#login_form_password input[name="user[username]"]))
      assert has_element?(lv, ~s(#login_form_password input[name="user[password]"]))
      refute has_element?(lv, "#login_form_magic")
      refute html =~ "Sign up"
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{username: user.username, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password", user: %{username: "nobody", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid username or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "registration" do
    test "has no public registration route", %{conn: conn} do
      assert conn |> get("/users/register") |> response(404)
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with username filled in", %{conn: conn, user: user} do
      {:ok, lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "You need to reauthenticate"

      assert has_element?(
               lv,
               ~s(#login_form_password input[name="user[username]"][value="#{user.username}"])
             )
    end
  end
end
