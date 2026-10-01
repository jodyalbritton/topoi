defmodule Topoi.Ingest do
  @moduledoc """
  Stage 1 entry points (PRD §8, §8.1): submit a URL or paste a
  transcript. Both are idempotent per video: a video already in the
  library is returned, never transcribed again.
  """
  alias Ecto.Multi
  alias Topoi.Ingest.Canonicalize
  alias Topoi.{Repo, Transcripts, Videos}
  alias Topoi.Transcripts.{Parsers, Transcript}
  alias Topoi.Workers

  @doc """
  Submits a video URL. Returns `{:ok, video}` (queued),
  `{:existing, video}` (already in the library; nothing queued), or
  `{:error, message}`.
  """
  def submit_url(url, debater_ids \\ [], extra_keyterms \\ []) do
    with {:ok, identity} <- Canonicalize.resolve(url, resolve_req_options()) do
      case Videos.get_video_by_platform_id(identity.platform, identity.platform_video_id) do
        nil -> create_and_enqueue(identity, debater_ids, extra_keyterms)
        video -> {:existing, video}
      end
    end
  end

  defp create_and_enqueue(identity, debater_ids, extra_keyterms) do
    attrs = Map.put(identity, :extra_keyterms, extra_keyterms)

    case Videos.create_video(attrs, debater_ids) do
      {:ok, video} ->
        {:ok, _job} = Oban.insert(Workers.Ingest.new(%{video_id: video.id}))
        {:ok, video}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Lost a race with an identical submit: return the winner.
        case Videos.get_video_by_platform_id(identity.platform, identity.platform_video_id) do
          nil -> {:error, error_message(changeset)}
          video -> {:existing, video}
        end
    end
  end

  @doc """
  Stores a pasted SRT-style transcript and queues normalization. With a
  `source_url`, the paste attaches to that video; a video that already
  has a live transcript is refused.
  """
  def submit_paste(text, source_url \\ nil, debater_ids \\ []) do
    with {:ok, segments} <- Parsers.srt_segments(text),
         {:ok, identity} <- paste_identity(source_url),
         {:ok, video} <- paste_video(identity, debater_ids) do
      Multi.new()
      |> Multi.insert(:transcript, fn _ ->
        Transcript.changeset(%Transcript{}, %{
          video_id: video.id,
          provider: "paste",
          status: "received",
          request_params: %{"segments" => length(segments)}
        })
      end)
      |> Multi.run(:words, fn _repo, %{transcript: t} ->
        Transcripts.put_words(t, Parsers.srt_words(segments))
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{transcript: t}} ->
          {:ok, video} = Videos.set_status(video, "transcribed")
          {:ok, _} = Oban.insert(Workers.Normalize.new(%{transcript_id: t.id}))
          {:ok, video}

        {:error, :transcript, changeset, _} ->
          {:error, error_message(changeset)}
      end
    end
  end

  @doc """
  Stores an ElevenLabs response obtained outside the app (e.g. an earlier
  manual run) as the video's transcript, without a new paid call, then
  queues normalization. Refused when the video already has a transcript.
  """
  def import_elevenlabs(url, %{"words" => _} = payload, debater_ids \\ []) do
    with {:ok, identity} <- Canonicalize.resolve(url, resolve_req_options()),
         {:ok, video} <- paste_video(identity, debater_ids) do
      duration_ms = payload["audio_duration_secs"] && round(payload["audio_duration_secs"] * 1000)

      Multi.new()
      |> Multi.insert(:transcript, fn _ ->
        Transcript.changeset(%Transcript{}, %{
          video_id: video.id,
          provider: "elevenlabs",
          provider_job_id: payload["transcription_id"],
          status: "received",
          request_params: %{"imported" => true},
          raw_payload: payload,
          language_code: payload["language_code"],
          audio_duration_ms: duration_ms
        })
      end)
      |> Multi.run(:words, fn _repo, %{transcript: t} ->
        Transcripts.put_words(t, Parsers.elevenlabs_words(payload))
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{transcript: t}} ->
          details =
            case Topoi.Metadata.fetch(identity) do
              {:ok, attrs} -> attrs
              {:error, _} -> %{}
            end

          {:ok, video} = Videos.put_metadata(video, Map.put(details, :duration_ms, duration_ms))
          {:ok, video} = Videos.set_status(video, "transcribed")
          {:ok, _} = Oban.insert(Workers.Normalize.new(%{transcript_id: t.id}))
          {:ok, video}

        {:error, :transcript, changeset, _} ->
          {:error, error_message(changeset)}
      end
    end
  end

  defp paste_identity(blank) when blank in [nil, ""], do: {:ok, %{platform: "none"}}
  defp paste_identity(url), do: Canonicalize.resolve(url, resolve_req_options())

  defp paste_video(%{platform: "none"}, debater_ids),
    do: Videos.create_video(%{platform: "none"}, debater_ids)

  defp paste_video(identity, debater_ids) do
    case Videos.get_video_by_platform_id(identity.platform, identity.platform_video_id) do
      nil ->
        Videos.create_video(identity, debater_ids)

      video ->
        if Transcripts.live_transcript(video.id),
          do: {:error, "That video already has a transcript."},
          else: {:ok, video}
    end
  end

  defp error_message(%Ecto.Changeset{errors: [{field, {msg, _}} | _]}), do: "#{field} #{msg}"
  defp error_message(_), do: "Could not save."

  defp resolve_req_options, do: Application.get_env(:topoi, Canonicalize, [])[:req_options] || []
end
