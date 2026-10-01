defmodule TopoiWeb.Admin.AdminAccessTest do
  use TopoiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures

  for path <- [
        "/admin",
        "/admin/gateway",
        "/admin/settings",
        "/admin/debates",
        "/admin/debaters",
        "/admin/debates/00000000-0000-0000-0000-000000000000/speakers"
      ] do
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

  test "the overview lists debates with speakers to review", %{conn: conn} do
    video = Topoi.IngestFixtures.video_fixture(%{}, [])
    {:ok, video} = Topoi.Videos.put_metadata(video, %{title: "A debate to review"})
    {:ok, _} = Topoi.Videos.set_status(video, "speakers_suggested")

    {:ok, _} =
      Topoi.Review.create_suggestion(%{
        video_id: video.id,
        kind: "format",
        value: "podcast",
        source: "model"
      })

    conn = log_in_user(conn, user_fixture() |> make_admin())
    {:ok, lv, html} = live(conn, ~p"/admin")
    assert html =~ "Needs review"

    assert has_element?(
             lv,
             ~s(a[href="/admin/debates/#{video.id}/speakers"]),
             "A debate to review"
           )
  end

  test "admins see the gateway page", %{conn: conn} do
    conn = log_in_user(conn, user_fixture() |> make_admin())
    {:ok, _lv, html} = live(conn, ~p"/admin/gateway")
    assert html =~ "No key saved."
  end
end
