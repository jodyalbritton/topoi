defmodule Topoi.IngestFixtures do
  @moduledoc "Test helpers for debaters, videos, and transcripts."

  alias Topoi.{Debaters, Transcripts, Videos}

  def debater_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, debater} =
      attrs
      |> Enum.into(%{slug: "debater-#{n}", name: "Debater #{n}"})
      |> Debaters.create_debater()

    debater
  end

  def video_fixture(attrs \\ %{}, debater_ids \\ []) do
    id = "vid#{System.unique_integer([:positive])}"

    {:ok, video} =
      attrs
      |> Enum.into(%{
        platform: "youtube",
        platform_video_id: id,
        canonical_url: "https://www.youtube.com/watch?v=#{id}"
      })
      |> Videos.create_video(debater_ids)

    video
  end

  def transcript_fixture(video, attrs \\ %{}) do
    {:ok, t} =
      attrs
      |> Enum.into(%{video_id: video.id, provider: "paste", status: "received"})
      |> Transcripts.create_transcript()

    t
  end
end
