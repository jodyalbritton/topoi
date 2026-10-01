defmodule Topoi.Workers.Ingest do
  @moduledoc """
  Stage 1 (PRD §8): metadata, then one ElevenLabs transcription, then
  hands off to normalization. Unique per video, so a video is never
  transcribed twice by concurrent jobs. Transient provider errors are
  retried with backoff; permanent ones fail the video with the message.
  """
  use Oban.Worker,
    queue: :ingest,
    max_attempts: 5,
    unique: [
      keys: [:video_id],
      period: :infinity,
      states: Oban.Job.states() -- [:completed, :discarded, :cancelled]
    ]

  require Logger

  alias Topoi.Ingest.Keyterms
  alias Topoi.{Metadata, Transcripts, Videos}
  alias Topoi.Transcripts.{ElevenLabs, Parsers}
  alias Topoi.Workers

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"video_id" => video_id}, attempt: attempt, max_attempts: max}) do
    video = Videos.get_video!(video_id)

    case Transcripts.live_transcript(video.id) do
      %{status: "received"} = t ->
        enqueue_normalize(t)

      pending ->
        video = with_metadata(video)
        {:ok, video} = Videos.set_status(video, "transcribing")
        transcribe(video, pending, attempt >= max)
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}), do: trunc(:math.pow(2, attempt) * 15)

  defp with_metadata(%{title: nil} = video) do
    case Metadata.fetch(Map.take(video, [:platform, :platform_video_id, :canonical_url])) do
      {:ok, attrs} ->
        {:ok, video} = Videos.put_metadata(video, attrs)
        video

      {:error, reason} ->
        Logger.info("metadata unavailable for #{video.id}: #{inspect(reason)}")
        video
    end
  end

  defp with_metadata(video), do: video

  defp transcribe(video, pending, last_attempt?) do
    {keyterms, _dropped} = Keyterms.build(video.debaters, video, video.extra_keyterms)
    num_speakers = if video.debaters == [], do: nil, else: max(length(video.debaters), 2)

    transcript = pending || create_pending!(video)

    case ElevenLabs.transcribe(video.canonical_url,
           keyterms: keyterms,
           num_speakers: num_speakers
         ) do
      {:ok, body, params} ->
        store(video, transcript, body, params)

      {:error, :not_configured} ->
        fail(
          video,
          transcript,
          "No ElevenLabs key saved. Add it at /admin/settings, then resubmit."
        )

        {:cancel, :not_configured}

      {:error, {:transient, message}} when not last_attempt? ->
        {:ok, _} = Videos.set_status(video, "transcribing", "Retrying: #{message}")
        {:error, message}

      {:error, {_kind, message}} ->
        fail(video, transcript, message)
        {:cancel, message}
    end
  end

  defp create_pending!(video) do
    {:ok, transcript} =
      Transcripts.create_transcript(%{
        video_id: video.id,
        provider: "elevenlabs",
        status: "pending"
      })

    transcript
  end

  defp store(video, transcript, body, params) do
    words = Parsers.elevenlabs_words(body)
    duration_ms = body["audio_duration_secs"] && round(body["audio_duration_secs"] * 1000)

    {:ok, transcript} =
      Transcripts.update_transcript(transcript, %{
        status: "received",
        provider_job_id: body["transcription_id"],
        request_params: params,
        raw_payload: body,
        language_code: body["language_code"],
        audio_duration_ms: duration_ms
      })

    {:ok, _} = Transcripts.put_words(transcript, words)
    {:ok, video} = Videos.put_metadata(video, %{duration_ms: duration_ms})
    {:ok, _} = Videos.set_status(video, "transcribed")
    enqueue_normalize(transcript)
  end

  defp fail(video, transcript, message) do
    {:ok, _} = Transcripts.update_transcript(transcript, %{status: "failed", error: message})
    {:ok, _} = Videos.set_status(video, "failed", message)
  end

  defp enqueue_normalize(transcript) do
    {:ok, _} = Oban.insert(Workers.Normalize.new(%{transcript_id: transcript.id}))
    :ok
  end
end
