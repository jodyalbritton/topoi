defmodule TopoiWeb.Admin.GatewayLiveTest do
  use TopoiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures

  alias Topoi.AI.Gateway
  alias Topoi.Settings
  alias Topoi.Settings.Gateway, as: Config

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture() |> make_admin())}
  end

  test "saves the key without rendering it, then tests the connection", %{conn: conn} do
    Req.Test.stub(Gateway, fn conn ->
      assert conn.request_path == "/v1/models"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer airo_secret"]

      Req.Test.json(conn, %{
        "data" => [
          %{"id" => "chat", "capabilities" => ["chat"]},
          %{"id" => "qwen3.5-9b", "capabilities" => ["chat"]},
          %{"id" => "embed-fast", "capabilities" => ["embeddings"]}
        ]
      })
    end)

    {:ok, lv, html} = live(conn, ~p"/admin/gateway")
    assert html =~ "No key saved."

    html =
      lv
      |> form("#gateway-form",
        gateway: %{base_url: "https://llm.local.joby.gg/", api_key: "airo_secret"}
      )
      |> render_submit()

    refute html =~ "airo_secret"
    assert Settings.get(Config).base_url == "https://llm.local.joby.gg"

    html = lv |> element("button", "Test connection") |> render_click()
    assert html =~ "Connected. 2 chat and 1 embedding models available."
    assert has_element?(lv, ~s(select[name="gateway[chat_model]"] option[value="qwen3.5-9b"]))
  end

  test "reports a rejected key in plain words", %{conn: conn} do
    Req.Test.stub(Gateway, fn conn ->
      conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "nope"})
    end)

    {:ok, _} = Settings.update(Config, %{api_key: "bad"})

    {:ok, lv, _} = live(conn, ~p"/admin/gateway")

    assert lv |> element("button", "Test connection") |> render_click() =~
             "The gateway rejected the key (401)."
  end

  test "test before saving asks for settings", %{conn: conn} do
    {:ok, lv, _} = live(conn, ~p"/admin/gateway")

    assert lv |> element("button", "Test connection") |> render_click() =~
             "Save a base URL and key first."
  end
end
