defmodule Topoi.AI.GatewayTest do
  use Topoi.DataCase, async: true

  alias Topoi.AI.Gateway
  alias Topoi.Settings

  test "not configured without a key" do
    assert {:error, :not_configured} = Gateway.chat([%{"role" => "user", "content" => "hi"}])
    refute Gateway.configured?()
  end

  test "chat sends the alias, strict json schema, and thinking off" do
    {:ok, _} = Settings.update(Topoi.Settings.Gateway, %{api_key: "k", chat_model: "chat-deep"})

    Req.Test.stub(Gateway, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      params = Jason.decode!(body)
      assert params["model"] == "chat-deep"
      assert params["chat_template_kwargs"] == %{"enable_thinking" => false}
      assert params["response_format"]["type"] == "json_schema"
      assert params["response_format"]["json_schema"]["strict"] == true
      Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => "{}"}}]})
    end)

    assert {:ok, %{"choices" => [_]}} =
             Gateway.chat([%{"role" => "user", "content" => "hi"}],
               json_schema: %{"name" => "x", "schema" => %{"type" => "object"}}
             )
  end
end
