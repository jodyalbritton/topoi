defmodule Topoi.Ingest.Canonicalize do
  @moduledoc """
  Maps any submitted URL to a video's identity, `(platform, id)`, and a
  canonical URL (PRD §8.1). Lookups and uniqueness use the identity,
  never the submitted string.

  TikTok short links (`vm.`, `vt.`, `/t/`, `m.tiktok.com/v/…`) carry no
  video id; `resolve/1` follows one redirect to find it. Everything else
  is parsed offline.
  """

  @youtube_hosts ~w(youtube.com www.youtube.com m.youtube.com music.youtube.com
                    youtube-nocookie.com www.youtube-nocookie.com)
  @youtube_id ~r/^[A-Za-z0-9_-]{11}$/
  @tiktok_hosts ~w(tiktok.com www.tiktok.com m.tiktok.com)
  @tiktok_short_hosts ~w(vm.tiktok.com vt.tiktok.com)

  @type identity :: %{
          platform: String.t(),
          platform_video_id: String.t(),
          canonical_url: String.t()
        }

  @doc """
  Parses `url` without network access. Returns `{:ok, identity}`,
  `{:short_link, url}` when a TikTok redirect must be followed, or
  `{:error, message}`.
  """
  @spec parse(String.t()) :: {:ok, identity} | {:short_link, String.t()} | {:error, String.t()}
  def parse(url) when is_binary(url) do
    url = String.trim(url)

    with {:ok, uri} <- to_uri(url) do
      host = String.downcase(uri.host)
      segments = path_segments(uri.path)

      cond do
        host in @youtube_hosts -> youtube(segments, query(uri))
        host == "youtu.be" -> youtube_id(List.first(segments))
        host in @tiktok_short_hosts -> {:short_link, url}
        host in @tiktok_hosts -> tiktok(host, segments, url)
        true -> {:error, "Only YouTube and TikTok video links are supported."}
      end
    end
  end

  def parse(_), do: {:error, "Enter a video link."}

  @doc """
  Like `parse/1`, but follows a TikTok short link's redirect once.
  `req_options` are merged into the Req request (tests pass a plug).
  """
  @spec resolve(String.t(), keyword) :: {:ok, identity} | {:error, String.t()}
  def resolve(url, req_options \\ []) do
    case parse(url) do
      {:short_link, short} -> follow(short, req_options)
      other -> other
    end
  end

  # -- YouTube

  defp youtube(["watch"], %{"v" => id}), do: youtube_id(id)
  defp youtube([kind, id | _], _q) when kind in ~w(shorts live embed v e), do: youtube_id(id)
  defp youtube(_, _), do: {:error, "That YouTube link does not point to a video."}

  defp youtube_id(id) when is_binary(id) do
    if Regex.match?(@youtube_id, id) do
      {:ok,
       %{
         platform: "youtube",
         platform_video_id: id,
         canonical_url: "https://www.youtube.com/watch?v=#{id}"
       }}
    else
      {:error, "That YouTube link does not point to a video."}
    end
  end

  defp youtube_id(_), do: {:error, "That YouTube link does not point to a video."}

  # -- TikTok

  defp tiktok(_host, ["@" <> handle, "video", id | _], _url) when handle != "" do
    if Regex.match?(~r/^\d{8,25}$/, id) do
      {:ok,
       %{
         platform: "tiktok",
         platform_video_id: id,
         canonical_url: "https://www.tiktok.com/@#{handle}/video/#{id}"
       }}
    else
      {:error, "That TikTok link does not point to a video."}
    end
  end

  defp tiktok(_host, ["@" <> _, "live" | _], _url),
    do: {:error, "TikTok live links have no replay; submit the video link instead."}

  defp tiktok(_host, ["t", _ | _], url), do: {:short_link, url}
  defp tiktok("m.tiktok.com", ["v", _ | _], url), do: {:short_link, url}
  defp tiktok(_, _, _), do: {:error, "That TikTok link does not point to a video."}

  defp follow(short, req_options) do
    opts = Keyword.merge([redirect: false, retry: false, receive_timeout: 10_000], req_options)

    case Req.get(short, opts) do
      {:ok, %Req.Response{status: status} = resp} when status in 300..399 ->
        case Req.Response.get_header(resp, "location") do
          [location | _] ->
            case parse(location) do
              {:ok, identity} -> {:ok, identity}
              _ -> {:error, "That TikTok link does not lead to a video."}
            end

          [] ->
            {:error, "That TikTok link does not lead to a video."}
        end

      {:ok, _} ->
        {:error, "That TikTok link does not lead to a video."}

      {:error, _} ->
        {:error, "Could not reach TikTok to resolve that link. Try the full video link."}
    end
  end

  # -- helpers

  defp to_uri(url) do
    url = if String.contains?(url, "://"), do: url, else: "https://" <> url

    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host} = uri}
      when scheme in ["http", "https"] and is_binary(host) ->
        {:ok, uri}

      _ ->
        {:error, "That is not a link."}
    end
  end

  defp path_segments(nil), do: []

  defp path_segments(path),
    do: path |> String.split("/", trim: true) |> Enum.map(&String.trim_trailing(&1, ".html"))

  defp query(%URI{query: nil}), do: %{}
  defp query(%URI{query: q}), do: URI.decode_query(q)
end
