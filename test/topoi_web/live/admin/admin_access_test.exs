defmodule TopoiWeb.Admin.AdminAccessTest do
  use TopoiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures

  for path <- ["/admin", "/admin/gateway", "/admin/settings", "/admin/debates", "/admin/debaters"] do
    test "#{path} sends anonymous visitors to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, unquote(path))
    end

    test "#{path} turns away signed-in non-admins", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, unquote(path))
    end
  end

  test "admins see the overview with setup state", %{conn: conn} do
    conn = log_in_user(conn, user_fixture() |> make_admin())
    {:ok, lv, html} = live(conn, ~p"/admin")

    assert html =~ "Overview"
    assert html =~ "AI gateway"
    assert has_element?(lv, ~s(a[href="/admin/gateway"]), "Configure")
  end

  test "admins see the gateway page", %{conn: conn} do
    conn = log_in_user(conn, user_fixture() |> make_admin())
    {:ok, _lv, html} = live(conn, ~p"/admin/gateway")
    assert html =~ "Not configured"
  end
end
