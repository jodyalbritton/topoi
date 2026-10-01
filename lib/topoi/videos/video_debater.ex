defmodule Topoi.Videos.VideoDebater do
  @moduledoc "An expected debater chosen at submit: a hint for keyterms and Gate A, not a confirmation."
  use Topoi.Schema

  schema "video_debaters" do
    belongs_to :video, Topoi.Videos.Video
    belongs_to :debater, Topoi.Debaters.Debater
    timestamps(updated_at: false)
  end
end
