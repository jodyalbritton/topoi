defmodule Topoi.Participants.Candidates do
  @moduledoc """
  Code suggestions from what is on record about the video itself
  (PRD §6, §9.2): debaters chosen as expected at submit, and a debater
  whose name or handle is the video's channel.

    * **Candidate links**: each such debater not already linked to a
      label by the model's suggestions is suggested for every label that
      has no linked debater, with the reasons as evidence. The admin
      confirms the right label and rejects the rest.
    * **Channel of record**: `debater` when the channel matches a debater
      record; otherwise no suggestion (it stays `unknown`).
  """
  import Ecto.Query, warn: false

  alias Topoi.{Debaters, Repo, Review}
  alias Topoi.Review.Suggestion
  alias Topoi.Videos.{Participant, Video}

  def suggest(%Video{} = video, call \\ nil) do
    video = Repo.preload(video, :debaters, force: true)
    debaters = Debaters.list_debaters()
    channel_debater = channel_debater(video, debaters)

    suggestions =
      Repo.all(
        from s in Suggestion,
          where: s.video_id == ^video.id and s.kind == "identity" and is_nil(s.superseded_at)
      )

    linked = suggestions |> Enum.map(& &1.debater_id) |> Enum.reject(&is_nil/1) |> MapSet.new()

    labels =
      Repo.all(
        from p in Participant,
          where: p.video_id == ^video.id,
          select: p.raw_label,
          order_by: p.raw_label
      )

    linked_labels = for s <- suggestions, s.debater_id, into: MapSet.new(), do: s.raw_label
    role_for = Map.new(suggestions, &{&1.raw_label, &1.value})

    candidates =
      (video.debaters ++ List.wrap(channel_debater))
      |> Enum.uniq_by(& &1.id)
      |> Enum.reject(&MapSet.member?(linked, &1.id))

    open_labels = Enum.reject(labels, &MapSet.member?(linked_labels, &1))

    links =
      for d <- candidates, label <- open_labels do
        reasons =
          [
            Enum.any?(video.debaters, &(&1.id == d.id)) &&
              "chosen as an expected debater at submit",
            channel_debater && channel_debater.id == d.id &&
              "the video is on this debater's channel (#{video.channel_name})"
          ]
          |> Enum.filter(& &1)

        %{
          video_id: video.id,
          kind: "identity",
          raw_label: label,
          value: Map.get(role_for, label, "guest"),
          stated_name: d.name,
          debater_id: d.id,
          evidence_quote:
            "Possibly #{d.name}: " <>
              Enum.join(reasons, "; ") <>
              "." <>
              if(length(open_labels) > 1,
                do:
                  " Suggested for #{length(open_labels)} speakers; confirm the one that is #{d.name}.",
                else: ""
              ),
          source: "code",
          llm_call_id: call && call.id
        }
      end

    channel =
      if channel_debater,
        do: [
          %{
            video_id: video.id,
            kind: "channel_of_record",
            value: "debater",
            debater_id: channel_debater.id,
            evidence_quote: "Channel: #{video.channel_name}",
            source: "code",
            llm_call_id: call && call.id
          }
        ],
        else: []

    Enum.count(links ++ channel, &match?({:ok, _}, Review.suggest(&1)))
  end

  @doc false
  def channel_debater(%Video{channel_name: name, channel_url: url}, debaters) do
    keys =
      [name, url && url |> String.split("@") |> List.last()]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&squash/1)

    Enum.find(debaters, fn d ->
      [d.name | d.handles] |> Enum.map(&squash/1) |> Enum.any?(&(&1 != "" and &1 in keys))
    end)
  end

  defp squash(s), do: s |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "")
end
