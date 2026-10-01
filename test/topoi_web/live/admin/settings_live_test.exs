defmodule TopoiWeb.Admin.SettingsLiveTest do
  use TopoiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures

  alias Topoi.Settings
  alias Topoi.Settings.{ElevenLabs, Pipeline}

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture() |> make_admin())}
  end

  test "saves a key without ever rendering it back", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/admin/settings")
    assert html =~ "No key saved."

    html =
      lv
      |> form("#elevenlabs-form", elevenlabs: %{api_key: "sk_live_should_not_render"})
      |> render_submit()

    assert html =~ "A key is saved."
    refute html =~ "sk_live_should_not_render"
    assert Settings.get(ElevenLabs).api_key == "sk_live_should_not_render"

    {:ok, _lv, html} = live(conn, ~p"/admin/settings")
    refute html =~ "sk_live_should_not_render"
  end

  test "saves pipeline thresholds and shows errors", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/admin/settings")

    lv |> form("#pipeline-form", pipeline: %{merge_gap_ms: 3500}) |> render_submit()
    assert Settings.get(Pipeline).merge_gap_ms == 3500

    html =
      lv
      |> form("#pipeline-form", pipeline: %{review_confidence_threshold: 2})
      |> render_submit()

    assert html =~ "must be less than or equal to 1.0"
  end
end
