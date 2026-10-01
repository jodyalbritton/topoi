defmodule Topoi.Transcripts.Parsers do
  @moduledoc """
  Provider output → layer-0 words (PRD §9). Both inputs land in the same
  word shape, so a pasted export and an API result go through the same
  normalization (§12.11 / Appendix D).

  Word maps: `%{text, kind, start_ms, end_ms, raw_label, logprob}` where
  `kind` is `"word"` or `"audio_event"` and `raw_label` is
  `"speaker_N"` for both sources.
  """

  @doc """
  Words from an ElevenLabs speech-to-text response (decoded JSON).
  Spacing tokens are dropped; audio events are kept as their own kind.
  """
  def elevenlabs_words(%{"words" => words}) when is_list(words) do
    for %{"type" => type} = w <- words, type in ["word", "audio_event"] do
      %{
        text: w["text"],
        kind: type,
        start_ms: to_ms(w["start"]),
        end_ms: to_ms(w["end"]),
        raw_label: w["speaker_id"] || "speaker_0",
        logprob: w["logprob"]
      }
    end
  end

  def elevenlabs_words(_), do: []

  @header ~r/^(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})\s*\[Speaker\s+(\d+)\]\s*$/m
  @tag ~r/\[Speaker\s+\d+\]/

  @doc """
  Parses an SRT-style export with `[Speaker N]` tags into segments.

  Splits on block *start* (each timestamp header), so the last block is
  kept even without a trailing blank line, then asserts that the number
  of segments equals the number of speaker tags (PRD §9.1 rule 6).
  """
  def srt_segments(text) when is_binary(text) do
    text = String.replace(text, "\r\n", "\n")
    headers = Regex.scan(@header, text, return: :index)
    tags = length(Regex.scan(@tag, text))

    segments =
      headers
      |> Enum.with_index()
      |> Enum.map(fn {[{start, len} | _], i} ->
        header = binary_part(text, start, len)
        body_start = start + len

        body_end =
          case Enum.at(headers, i + 1) do
            [{next, _} | _] -> next
            nil -> byte_size(text)
          end

        body = text |> binary_part(body_start, body_end - body_start) |> String.trim()
        [_, h1, m1, s1, ms1, h2, m2, s2, ms2, spk] = Regex.run(@header, header)

        %{
          start_ms: clock(h1, m1, s1, ms1),
          end_ms: clock(h2, m2, s2, ms2),
          raw_label: "speaker_" <> spk,
          text: body
        }
      end)

    cond do
      segments == [] ->
        {:error,
         "No timed [Speaker N] blocks found. Paste an SRT-style export with speaker tags."}

      length(segments) != tags ->
        {:error,
         "Found #{tags} speaker tags but parsed #{length(segments)} blocks; the paste is malformed."}

      true ->
        {:ok, segments}
    end
  end

  @doc """
  Words from parsed SRT segments. A segment's time is shared evenly
  across its words, which is enough for turn rules and seeking; the
  provider JSON gives true word timings when available.
  """
  def srt_words(segments) do
    Enum.flat_map(segments, fn %{start_ms: s, end_ms: e, raw_label: label, text: text} ->
      tokens = String.split(text, ~r/\s+/, trim: true)
      n = max(length(tokens), 1)
      step = (e - s) / n

      tokens
      |> Enum.with_index()
      |> Enum.map(fn {token, i} ->
        %{
          text: token,
          kind: if(Regex.match?(~r/^\[[^\]]+\]$/, token), do: "audio_event", else: "word"),
          start_ms: round(s + i * step),
          end_ms: round(s + (i + 1) * step),
          raw_label: label,
          logprob: nil
        }
      end)
    end)
  end

  defp to_ms(nil), do: 0
  defp to_ms(seconds) when is_number(seconds), do: round(seconds * 1000)

  defp clock(h, m, s, ms),
    do:
      String.to_integer(h) * 3_600_000 + String.to_integer(m) * 60_000 +
        String.to_integer(s) * 1000 + String.to_integer(ms)
end
