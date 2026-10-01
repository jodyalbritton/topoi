defmodule Topoi.Transcripts.ElevenLabs do
  @moduledoc """
  ElevenLabs speech-to-text (PRD §8.2). One synchronous request per
  video; the key and model come from `Topoi.Settings.ElevenLabs`.

  Errors are classified so the worker knows whether to retry:
  `{:error, {:transient, message}}` (upstream download failures, 429,
  5xx, timeouts) or `{:error, {:permanent, message}}` (anything else),
  or `{:error, :not_configured}`.
  """

  alias Topoi.Settings
  alias Topoi.Settings.ElevenLabs, as: Config

  @endpoint "https://api.elevenlabs.io/v1/speech-to-text"
  @receive_timeout 600_000

  @doc """
  Transcribes `source_url`. Options: `:keyterms` (list), `:num_speakers`
  (integer or nil), `:req_options` (merged into the request; tests pass
  a plug). Returns `{:ok, response_body, request_params}`.
  """
  def transcribe(source_url, opts \\ []) do
    config = Settings.get(Config)

    if Config.configured?(config) do
      params = request_params(source_url, config, opts)

      req_opts =
        [
          headers: [{"xi-api-key", config.api_key}],
          form_multipart: to_multipart(params),
          receive_timeout: @receive_timeout,
          retry: false
        ]
        |> Keyword.merge(configured_req_options())
        |> Keyword.merge(Keyword.get(opts, :req_options, []))

      case Req.post(@endpoint, req_opts) do
        {:ok, %Req.Response{status: 200, body: %{} = body}} -> {:ok, body, params}
        {:ok, %Req.Response{status: status, body: body}} -> {:error, classify(status, body)}
        {:error, exception} -> {:error, {:transient, Exception.message(exception)}}
      end
    else
      {:error, :not_configured}
    end
  end

  @doc "The exact parameters sent, stored on the transcript row (never the key)."
  def request_params(source_url, %Config{} = config, opts) do
    %{
      "model_id" => config.model_id,
      "source_url" => source_url,
      "diarize" => true,
      "timestamps_granularity" => "word",
      "tag_audio_events" => true,
      "no_verbatim" => false,
      "seed" => config.seed,
      "keyterms" => Keyword.get(opts, :keyterms, []),
      "num_speakers" => Keyword.get(opts, :num_speakers)
    }
  end

  # Lists become repeated fields; nil and empty values are omitted.
  defp to_multipart(params) do
    Enum.flat_map(params, fn
      {_k, nil} -> []
      {_k, []} -> []
      {k, list} when is_list(list) -> Enum.map(list, &{String.to_atom(k), &1})
      {k, v} when is_boolean(v) or is_integer(v) -> [{String.to_atom(k), to_string(v)}]
      {k, v} -> [{String.to_atom(k), v}]
    end)
  end

  defp classify(status, body) do
    message = message(body) || "HTTP #{status}"

    cond do
      status == 429 or status >= 500 -> {:transient, message}
      status == 400 and message =~ "Failed to download" -> {:transient, message}
      true -> {:permanent, message}
    end
  end

  defp message(%{"detail" => %{"message" => m}}) when is_binary(m), do: m
  defp message(%{"detail" => m}) when is_binary(m), do: m
  defp message(_), do: nil

  defp configured_req_options, do: Application.get_env(:topoi, __MODULE__, [])[:req_options] || []
end
