defmodule Topoi.Transcripts.Normalize do
  @moduledoc """
  Layer 2 (PRD §9.1): words → turns, by deterministic rules whose
  thresholds come from `Topoi.Settings.Pipeline`.

  1. **Merge**: consecutive words by one speaker belong to one turn
     while the gap between them is ≤ `merge_gap_ms`; a turn ends when the
     other speaker holds the floor.
  2. **Backchannel**: a turn shorter than `backchannel_max_ms`, with at
     most `backchannel_max_words` words and no `?`, is kept but marked.
  3. **Bridge**: a speaker's turn followed only by backchannels and then
     the same speaker again within `bridge_window_ms` is one turn.
  4. **Interrupted**: a turn whose text starts with `...` or ends with a
     cut-off (`-`, `—`), or that absorbed such a part in a bridge.

  Fillers are never removed here; stripping is a display concern (rule 5).
  Audio events are not part of any turn. A bridged turn's word range can
  enclose the other speaker's backchannel words; its text is the turn
  speaker's words in that range.
  """

  alias Topoi.{Settings, Transcripts, Videos}
  alias Topoi.Settings.Pipeline
  alias Topoi.Transcripts.Transcript

  @doc """
  Normalizes a stored transcript: builds turns from its words with the
  saved settings, replaces its turns, creates one participant per raw
  label, and marks the video normalized. Returns `{:ok, stats}`.
  """
  def run(%Transcript{} = transcript) do
    words = Transcripts.list_words(transcript.id)
    {turns, stats} = build(words, Settings.get(Pipeline))

    with {:ok, _} <- Transcripts.put_turns(transcript, turns) do
      video = Videos.get_video!(transcript.video_id)
      Videos.ensure_participants(video, Enum.map(turns, & &1.raw_label))
      {:ok, _} = Videos.set_status(video, "normalized")
      {:ok, stats}
    end
  end

  @type stats :: %{
          turns_before_bridge: non_neg_integer,
          backchannel: non_neg_integer,
          substantive: non_neg_integer
        }

  @doc """
  Builds turns from indexed words (`%{idx, text, kind, start_ms, end_ms,
  raw_label}`, in order). Returns `{turns, stats}`.
  """
  @spec build([map], Pipeline.t() | map) :: {[map], stats}
  def build(words, %{} = settings) do
    spoken = Enum.filter(words, &(&1.kind == "word"))

    runs = merge(spoken, settings.merge_gap_ms)
    marked = Enum.map(runs, &mark_backchannel(&1, settings))
    bridged = bridge(marked, settings.bridge_window_ms)

    turns =
      bridged
      |> Enum.sort_by(&{&1.start_ms, &1.first_word_idx})
      |> Enum.map(&Map.drop(&1, [:text]))

    stats = %{
      turns_before_bridge: length(runs),
      backchannel: Enum.count(marked, &(&1.kind == "backchannel")),
      substantive: Enum.count(bridged, &(&1.kind == "substantive"))
    }

    {turns, stats}
  end

  # Rule 1. Speaker change always splits; a long pause within one
  # speaker's words splits too.
  defp merge(words, gap_ms) do
    words
    |> Enum.chunk_while(
      nil,
      fn w, acc ->
        cond do
          acc == nil ->
            {:cont, start_turn(w)}

          acc.raw_label == w.raw_label and w.start_ms - acc.end_ms <= gap_ms ->
            {:cont, extend(acc, w)}

          true ->
            {:cont, finish(acc), start_turn(w)}
        end
      end,
      fn
        nil -> {:cont, nil}
        acc -> {:cont, finish(acc), nil}
      end
    )
    |> Enum.reject(&is_nil/1)
  end

  defp start_turn(w) do
    %{
      raw_label: w.raw_label,
      first_word_idx: w.idx,
      last_word_idx: w.idx,
      start_ms: w.start_ms,
      end_ms: w.end_ms,
      word_count: 1,
      tokens: [w.text]
    }
  end

  defp extend(acc, w) do
    %{
      acc
      | last_word_idx: w.idx,
        end_ms: max(acc.end_ms, w.end_ms),
        word_count: acc.word_count + 1,
        tokens: [w.text | acc.tokens]
    }
  end

  defp finish(acc) do
    text = acc.tokens |> Enum.reverse() |> Enum.join(" ")

    acc
    |> Map.delete(:tokens)
    |> Map.merge(%{text: text, interrupted: interrupted?(text)})
  end

  defp interrupted?(text) do
    trimmed = String.trim(text)

    String.starts_with?(trimmed, ["...", "…"]) or
      String.ends_with?(trimmed, ["-", "—", "–"])
  end

  # Rule 2. Word count uses alphabetic words, so "Um-" and "5:49" do not
  # inflate it.
  defp mark_backchannel(turn, settings) do
    alpha_words = length(Regex.scan(~r/[A-Za-z']+/, turn.text))

    backchannel? =
      turn.end_ms - turn.start_ms < settings.backchannel_max_ms and
        alpha_words <= settings.backchannel_max_words and
        not String.contains?(turn.text, "?")

    Map.put(turn, :kind, if(backchannel?, do: "backchannel", else: "substantive"))
  end

  # Rule 3. Walk in order, keeping backchannels as they are; a substantive
  # turn joins the last substantive turn when that turn is the same
  # speaker's and only backchannels lie between them, within the window.
  defp bridge(turns, window_ms) do
    turns
    |> Enum.reduce([], fn
      %{kind: "backchannel"} = bc, acc ->
        [bc | acc]

      turn, acc ->
        case last_substantive(acc) do
          {i, prev}
          when prev.raw_label == turn.raw_label and turn.start_ms - prev.end_ms <= window_ms ->
            merged = %{
              prev
              | last_word_idx: turn.last_word_idx,
                end_ms: max(prev.end_ms, turn.end_ms),
                word_count: prev.word_count + turn.word_count,
                interrupted: prev.interrupted or turn.interrupted
            }

            List.replace_at(acc, i, merged)

          _ ->
            [turn | acc]
        end
    end)
    |> Enum.reverse()
  end

  # `acc` is newest-first; returns {index_in_acc, turn} of the most recent
  # substantive turn.
  defp last_substantive(acc) do
    acc
    |> Enum.with_index()
    |> Enum.find_value(fn {t, i} -> if t.kind == "substantive", do: {i, t} end)
  end
end
