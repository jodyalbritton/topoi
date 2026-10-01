defmodule Topoi.Videos do
  @moduledoc "Videos, their expected debaters, and raw participants."
  import Ecto.Query, warn: false

  alias Topoi.Debaters.Debater
  alias Topoi.Repo
  alias Topoi.Videos.{Participant, Video}

  @topic "videos"

  @doc "Subscribe to `{:video_updated, video_id}` messages."
  def subscribe, do: Phoenix.PubSub.subscribe(Topoi.PubSub, @topic)

  defp broadcast({:ok, %Video{id: id}} = result) do
    Phoenix.PubSub.broadcast(Topoi.PubSub, @topic, {:video_updated, id})
    result
  end

  defp broadcast(other), do: other

  def list_videos do
    Repo.all(from v in Video, order_by: [desc: v.inserted_at], preload: :debaters)
  end

  def get_video!(id), do: Video |> Repo.get!(id) |> Repo.preload(:debaters)

  def get_video_by_platform_id(platform, platform_video_id) do
    Repo.get_by(Video, platform: platform, platform_video_id: platform_video_id)
  end

  @doc "Inserts a video row. Duplicates fail on the unique index (PRD §8.1)."
  def create_video(attrs, debater_ids \\ []) do
    debaters = Repo.all(from d in Debater, where: d.id in ^debater_ids)

    %Video{}
    |> Video.create_changeset(attrs)
    |> Ecto.Changeset.put_assoc(:debaters, debaters)
    |> Repo.insert()
    |> broadcast()
  end

  def put_metadata(%Video{} = video, attrs) do
    video |> Video.metadata_changeset(attrs) |> Repo.update() |> broadcast()
  end

  def set_status(%Video{} = video, status, error \\ nil) do
    video |> Video.status_changeset(status, error) |> Repo.update() |> broadcast()
  end

  @doc "Creates one participant row per distinct raw label (idempotent)."
  def ensure_participants(%Video{id: video_id}, raw_labels) do
    now = DateTime.utc_now(:second)

    rows =
      for label <- Enum.uniq(raw_labels),
          do: %{
            id: Ecto.UUID.generate(),
            video_id: video_id,
            raw_label: label,
            confirmed_by_user: false,
            inserted_at: now,
            updated_at: now
          }

    Repo.insert_all(Participant, rows,
      on_conflict: :nothing,
      conflict_target: [:video_id, :raw_label]
    )

    Repo.all(from p in Participant, where: p.video_id == ^video_id, order_by: p.raw_label)
  end
end
