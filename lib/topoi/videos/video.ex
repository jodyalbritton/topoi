defmodule Topoi.Videos.Video do
  @moduledoc """
  One recorded debate. Identity is `(platform, platform_video_id)`
  (PRD §8.1); a paste with no source URL has platform `none`.
  """
  use Topoi.Schema

  @platforms ~w(youtube tiktok none)
  @statuses ~w(submitted transcribing transcribed normalized failed)
  @formats ~w(tiktok_live youtube_live moderated_formal podcast monologue)
  @channels ~w(debater opponent third_party unknown)

  schema "videos" do
    field :platform, :string
    field :platform_video_id, :string
    field :canonical_url, :string
    field :title, :string
    field :channel_name, :string
    field :channel_url, :string
    field :thumbnail_url, :string
    field :published_at, :utc_datetime
    field :duration_ms, :integer
    field :format, :string
    field :channel_of_record, :string, default: "unknown"
    field :status, :string, default: "submitted"
    field :last_error, :string
    field :extra_keyterms, {:array, :string}, default: []

    many_to_many :debaters, Topoi.Debaters.Debater,
      join_through: Topoi.Videos.VideoDebater,
      on_replace: :delete

    has_many :transcripts, Topoi.Transcripts.Transcript
    has_many :participants, Topoi.Videos.Participant

    timestamps()
  end

  def statuses, do: @statuses

  def create_changeset(video, attrs) do
    video
    |> cast(attrs, [:platform, :platform_video_id, :canonical_url, :extra_keyterms])
    |> validate_required([:platform])
    |> validate_inclusion(:platform, @platforms)
    |> validate_platform_id()
    |> unique_constraint([:platform, :platform_video_id],
      name: :videos_platform_video_id_index,
      message: "has already been submitted"
    )
  end

  def metadata_changeset(video, attrs) do
    video
    |> cast(attrs, [
      :title,
      :channel_name,
      :channel_url,
      :thumbnail_url,
      :published_at,
      :duration_ms
    ])
  end

  def review_changeset(video, attrs) do
    video
    |> cast(attrs, [:format, :channel_of_record, :published_at])
    |> validate_inclusion(:format, @formats)
    |> validate_inclusion(:channel_of_record, @channels)
  end

  def status_changeset(video, status, error \\ nil) do
    video
    |> change(status: status, last_error: error)
    |> validate_inclusion(:status, @statuses)
  end

  defp validate_platform_id(changeset) do
    case get_field(changeset, :platform) do
      "none" -> changeset
      _ -> validate_required(changeset, [:platform_video_id, :canonical_url])
    end
  end
end
