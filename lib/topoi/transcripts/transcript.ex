defmodule Topoi.Transcripts.Transcript do
  @moduledoc """
  A provider result for one video (PRD §12.1). At most one live
  (pending or received) transcript per video; re-transcription creates a
  new row that supersedes the old one, so existing spans still resolve.
  """
  use Topoi.Schema

  @providers ~w(elevenlabs paste)
  @statuses ~w(pending received failed superseded)

  schema "transcripts" do
    field :provider, :string
    field :provider_job_id, :string
    field :status, :string, default: "pending"
    field :request_params, :map, default: %{}
    field :raw_payload, :map
    field :language_code, :string
    field :audio_duration_ms, :integer
    field :error, :string

    belongs_to :video, Topoi.Videos.Video
    belongs_to :supersedes, __MODULE__
    has_many :words, Topoi.Transcripts.Word
    has_many :turns, Topoi.Transcripts.Turn

    timestamps()
  end

  def changeset(transcript, attrs) do
    transcript
    |> cast(attrs, [
      :video_id,
      :provider,
      :provider_job_id,
      :status,
      :request_params,
      :raw_payload,
      :language_code,
      :audio_duration_ms,
      :error,
      :supersedes_id
    ])
    |> validate_required([:video_id, :provider, :status])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:video_id,
      name: :transcripts_one_live_per_video_index,
      message: "already has a live transcript"
    )
  end
end
