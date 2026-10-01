defmodule Topoi.AI.Calls do
  @moduledoc """
  Runs a structured gateway call and logs it. Every suggestion links to
  the call that produced it, so a reviewer can see exactly what the model
  was asked and what it answered. Failures are logged and returned, never
  raised.
  """
  import Ecto.Query, warn: false

  alias Topoi.AI.{Call, Gateway}
  alias Topoi.Repo

  @doc """
  Options: `:purpose`, `:prompt_version`, `:messages`, `:schema`
  (`%{"name" => ..., "schema" => ...}`), `:video_id`. Returns
  `{:ok, parsed_map, call}` or `{:error, status, call}` where status is
  one of `not_configured | http_error | transport_error | invalid_json |
  invalid_shape`.
  """
  def run(opts) do
    schema = Keyword.fetch!(opts, :schema)
    messages = Keyword.fetch!(opts, :messages)
    started = System.monotonic_time(:millisecond)
    result = Gateway.chat(messages, json_schema: schema)
    latency = System.monotonic_time(:millisecond) - started

    base = %{
      purpose: Keyword.fetch!(opts, :purpose),
      prompt_version: Keyword.fetch!(opts, :prompt_version),
      video_id: Keyword.get(opts, :video_id),
      request: %{"messages" => messages, "schema" => schema},
      latency_ms: latency
    }

    attrs = Map.merge(base, outcome(result, schema))
    call = Repo.insert!(struct(Call, attrs))

    case call.status do
      "ok" -> {:ok, call.parsed, call}
      status -> {:error, String.to_atom(status), call}
    end
  end

  def get_call!(id), do: Repo.get!(Call, id)

  def list_calls(video_id) do
    Repo.all(from c in Call, where: c.video_id == ^video_id, order_by: [desc: c.inserted_at])
  end

  defp outcome({:error, :not_configured}, _),
    do: %{status: "not_configured", error: "Gateway not configured"}

  defp outcome({:error, {:http, s, body}}, _),
    do: %{status: "http_error", error: "HTTP #{s}: #{inspect(body)}"}

  defp outcome({:error, other}, _), do: %{status: "transport_error", error: inspect(other)}

  defp outcome({:ok, body}, schema) do
    content = get_in(body, ["choices", Access.at(0), "message", "content"])
    meta = %{model: body["model"], served_model: body["model"], content: content}

    with true <- is_binary(content) || {:error, "no content in the response"},
         {:ok, parsed} <- Jason.decode(content),
         :ok <- check_required(parsed, schema["schema"]) do
      Map.merge(meta, %{status: "ok", parsed: parsed})
    else
      {:error, %Jason.DecodeError{} = e} ->
        Map.merge(meta, %{status: "invalid_json", error: Exception.message(e)})

      {:error, message} ->
        Map.merge(meta, %{status: "invalid_shape", error: message})
    end
  end

  # Top-level shape check; callers validate each item further.
  defp check_required(parsed, %{"required" => required}) when is_map(parsed) do
    case Enum.reject(required, &Map.has_key?(parsed, &1)) do
      [] -> :ok
      missing -> {:error, "missing keys: #{Enum.join(missing, ", ")}"}
    end
  end

  defp check_required(parsed, _) when is_map(parsed), do: :ok
  defp check_required(_, _), do: {:error, "response is not a JSON object"}
end
