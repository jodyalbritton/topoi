defmodule TopoiWeb.PublicPagesTest do
  use TopoiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures

  test "home opens on search, then the library sections", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/")

    assert has_element?(lv, ~s(main form[action="/search"] input[name="q"][autofocus]))
    assert has_element?(lv, ~s(main a[href="/debates"]), "All")
    assert has_element?(lv, ~s(main a[href="/debaters"]), "All")
    assert has_element?(lv, ~s(header a[href="/about"]), "About")
    assert has_element?(lv, ~s(header a[href="/users/log-in"]), "Sign in")
    assert render(lv) =~ "© #{Date.utc_today().year} Topoi"
  end

  test "about explains Topoi", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/about")
    assert html =~ "About Topoi"
    assert html =~ "recorded public debates"
  end

  for {path, title} <- [
        {"/debaters", "Debaters"},
        {"/debates", "Debates"},
        {"/topics", "Topics"},
        {"/tags", "Tags"},
        {"/schools", "Schools"}
      ] do
    test "#{path} renders its section with an empty state", %{conn: conn} do
      {:ok, _lv, html} = live(conn, unquote(path))
      assert html =~ unquote(title)
      assert html =~ "None published yet."
    end
  end

  test "search echoes the query in the page and the header box", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/search?q=potency")

    assert html =~ "Results for “potency”"
    assert has_element?(lv, ~s(form[action="/search"] input[name="q"][value="potency"]))
  end

  test "pages carry social card meta", %{conn: conn} do
    html = conn |> get(~p"/topics") |> html_response(200)

    assert html =~ ~s(<meta property="og:title" content="Topics")
    assert html =~ ~s(<meta name="twitter:card" content="summary")
  end

  test "header shows the admin link only to admins", %{conn: conn} do
    user = user_fixture()
    {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/")
    refute html =~ ~s(href="/admin")
    assert html =~ user.username
    assert html =~ ~s(data-method="delete")
    refute html =~ ~s(href="/users/log-in")

    admin = user_fixture() |> make_admin()
    {:ok, _lv, html} = build_conn() |> log_in_user(admin) |> live(~p"/")
    assert html =~ ~s(href="/admin")
  end
end
