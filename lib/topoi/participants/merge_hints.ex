defmodule Topoi.Participants.MergeHints do
  @moduledoc """
  Code-only merge hints (PRD §9.2): diarization sometimes moves one
  person onto a new label mid-debate (observed on `cPVtaKPLC9Q`, where
  the affirmative's closing statement landed on a fifth label).

  A **handoff** is flagged when label B first speaks within
  `@handoff_ms` of a turn by label A that ends mid-sentence (no closing
  punctuation), and A is silent for B's entire span. That covers both a
  permanent relabel and a temporary one (the observed case: the fifth
  label held the closing statement, then the original label resumed).
  The hint is a suggestion like any other; a human confirms it.
  """
  alias Topoi.{Review, Transcripts}

  @handoff_ms 5_000

  @doc "Creates merge suggestions (`source: code`) and returns how many."
  def suggest(video, transcript, call \\ nil) do
    turns = Transcripts.turns_with_text(transcript.id, 100_000)
    existing = existing_pairs(video.id)

    turns
    |> handoffs()
    |> Enum.reject(fn {from, to, _, _} -> MapSet.member?(existing, {from, to}) end)
    |> Enum.count(fn {from, to, quote, ms} ->
      match?(
        {:ok, _},
        Review.suggest(%{
          video_id: video.id,
          kind: "merge",
          raw_label: from,
          merge_with_label: to,
          evidence_quote: quote,
          evidence_ms: ms,
          source: "code",
          llm_call_id: call && call.id
        })
      )
    end)
  end

  @doc """
  Returns `[{later_label, earlier_label, evidence, ms}]` for each handoff
  in ordered turns.
  """
  def handoffs(turns) do
    by_label = Enum.group_by(turns, & &1.raw_label)

    for {b, b_turns} <- by_label,
        {a, a_turns} <- by_label,
        a != b,
        first_b = hd(b_turns),
        last_b = List.last(b_turns),
        prev_a = a_turns |> Enum.filter(&(&1.end_ms <= first_b.start_ms + 500)) |> List.last(),
        prev_a != nil,
        gap = first_b.start_ms - prev_a.end_ms,
        gap <= @handoff_ms,
        not ends_sentence?(prev_a.text),
        silent_during?(a_turns, first_b.start_ms, last_b.end_ms) do
      evidence =
        "#{a} stops mid-sentence (\"…#{tail(prev_a.text)}\") and is silent while #{b} speaks; " <>
          "#{b} starts #{Float.round(max(gap, 0) / 1000, 1)} s later: \"#{head(first_b.text)}…\""

      {b, a, evidence, first_b.start_ms}
    end
  end

  defp silent_during?(turns, from, to),
    do: not Enum.any?(turns, &(&1.start_ms >= from and &1.start_ms <= to))

  defp ends_sentence?(text), do: String.match?(String.trim(text), ~r/[.?!"”)\]]$/u)

  defp tail(text), do: text |> String.split() |> Enum.take(-6) |> Enum.join(" ")
  defp head(text), do: text |> String.split() |> Enum.take(8) |> Enum.join(" ")

  defp existing_pairs(video_id) do
    Review.suggestions_by_label(video_id)
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(&(&1.kind == "merge"))
    |> MapSet.new(&{&1.raw_label, &1.merge_with_label})
  end
end
