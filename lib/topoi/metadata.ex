defmodule Topoi.Metadata do
  @moduledoc """
  Keyless video details (PRD §7): title, channel, and thumbnail from
  oEmbed. TikTok `published_at` comes from the video id (its top 32
  bits are Unix seconds). YouTube `published_at` stays empty until a Data
  API key exists; it is entered at Gate A.

  Best effort: a failure here never blocks ingest.
  """

  @endpoints %{
    "youtube" => "https://www.youtube.com/oembed",
    "tiktok" => "https://www.tiktok.com/oembed"
  }

  @doc """
  Fetches details for a canonical identity. Returns `{:ok, attrs}` with
  keys matching `Topoi.Videos.Video.metadata_changeset/2`, or
  `{:error, reason}`.
  """
  def fetch(identity, req_options \\ [])

  def fetch(%{platform: platform, canonical_url: url} = identity, req_options)
      when is_map_key(@endpoints, platform) do
    opts =
      [params: [url: url, format: "json"], retry: false, receive_timeout: 10_000]
      |> Keyword.merge(configured_req_options())
      |> Keyword.merge(req_options)

    case Req.get(@endpoints[platform], opts) do
      {:ok, %Req.Response{status: 200, body: %{} = body}} ->
        {:ok, Map.merge(from_oembed(body), published_at(identity))}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  def fetch(_identity, _opts), do: {:error, :unsupported_platform}

  @doc "Upload time encoded in a TikTok video id."
  def tiktok_published_at(id) when is_binary(id) do
    with {n, ""} <- Integer.parse(id),
         {:ok, dt} <- DateTime.from_unix(Bitwise.bsr(n, 32)) do
      dt
    else
      _ -> nil
    end
  end

  defp from_oembed(body) do
    %{
      title: body["title"],
      channel_name: body["author_name"],
      channel_url: body["author_url"],
      thumbnail_url: body["thumbnail_url"]
    }
  end

  defp published_at(%{platform: "tiktok", platform_video_id: id}),
    do: %{published_at: tiktok_published_at(id)}

  defp published_at(_), do: %{}

  defp configured_req_options, do: Application.get_env(:topoi, __MODULE__, [])[:req_options] || []
end
