defmodule Topoi.AI.CallsTest do
  use Topoi.DataCase, async: true

  alias Topoi.AI.{Calls, Gateway}
  alias Topoi.Settings

  @schema %{
    "name" => "t",
    "schema" => %{
      "type" => "object",
      "required" => ["speakers"],
      "properties" => %{"speakers" => %{"type" => "array"}}
    }
  }

  defp run,
    do:
      Calls.run(
        purpose: "test",
        prompt_version: "t1",
        messages: [%{"role" => "user", "content" => "x"}],
        schema: @schema
      )

  defp reply(content) do
    Req.Test.stub(Gateway, fn conn ->
      Req.Test.json(conn, %{
        "model" => "qwen-x",
        "choices" => [%{"message" => %{"content" => content}}]
      })
    end)
  end

  setup do
    {:ok, _} = Settings.update(Topoi.Settings.Gateway, %{api_key: "k"})
    :ok
  end

  test "logs a good call with the parsed answer" do
    reply(~s({"speakers": []}))
    assert {:ok, %{"speakers" => []}, call} = run()
    assert call.status == "ok"
    assert call.served_model == "qwen-x"
    assert call.prompt_version == "t1"
    assert call.request["messages"] == [%{"role" => "user", "content" => "x"}]
    assert is_integer(call.latency_ms)
  end

  test "logs invalid JSON and missing keys instead of raising" do
    reply("not json")
    assert {:error, :invalid_json, %{status: "invalid_json"}} = run()

    reply(~s({"other": 1}))
    assert {:error, :invalid_shape, %{error: "missing keys: speakers"}} = run()
  end

  test "logs HTTP errors and missing configuration" do
    Req.Test.stub(Gateway, fn conn -> conn |> Plug.Conn.put_status(503) |> Req.Test.json(%{}) end)
    assert {:error, :http_error, _} = run()

    Repo.delete_all(Topoi.Settings.Gateway)
    assert {:error, :not_configured, _} = run()
    assert Repo.aggregate(Topoi.AI.Call, :count) == 2
  end
end
