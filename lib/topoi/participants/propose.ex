defmodule Topoi.Participants.Propose do
  @moduledoc """
  Stage 3 suggestions (PRD §9.2, §10.1, prompt `participants-v1`).

  The model sees the first five minutes of turns plus the video's title
  and channel, and suggests, per speaker label: role, the name as stated
  on the record, position, and whether the label is the same person as
  another. Every claim must come with a verbatim quote.

  Code then decides what becomes a suggestion:

    * a quote that is not found in the window's turns, the title, or the
      channel name drops that claim (logged on the call);
    * stated names are matched to debater names and handles by code; the
      model is never shown the debater records, so it cannot be steered
      toward names already in the library;
    * positions outside the curated vocabulary are dropped.

  Nothing here changes the record; a human confirms at Gate A (§13).
  """
  require Logger

  alias Topoi.AI.Calls
  alias Topoi.{Debaters, Review, Transcripts, Videos}
  alias Topoi.Participants.{Candidates, MergeHints}
  alias Topoi.Transcripts.Transcript

  @prompt_version "participants-v4"
  @window_ms 5 * 60_000
  @late_turns 3
  @roles ~w(host guest moderator opponent)
  @formats ~w(tiktok_live youtube_live moderated_formal podcast monologue)

  def prompt_version, do: @prompt_version

  @doc """
  Proposes suggestions for a normalized transcript's video. Clears the
  video's undecided suggestions first, so a re-run replaces them.
  Returns `{:ok, %{created: n, dropped: [reason]}}` or `{:error, status}`.
  """
  def run(%Transcript{} = transcript) do
    video = Videos.get_video!(transcript.video_id)
    turns = window_turns(transcript)
    labels = turns |> Enum.map(& &1.raw_label) |> Enum.uniq() |> Enum.sort()
    all_labels = Videos.ensure_participants(video, []) |> Enum.map(& &1.raw_label)
    positions = Review.position_slugs()

    case Calls.run(
           purpose: "participants",
           prompt_version: @prompt_version,
           video_id: video.id,
           messages: messages(video, turns),
           schema: schema(Enum.uniq(all_labels ++ labels), positions)
         ) do
      {:ok, parsed, call} ->
        Review.clear_pending(video.id)
        corpus = corpus(video, turns)
        {created, dropped} = build(parsed, video, turns, corpus, positions, call)
        hints = MergeHints.suggest(video, transcript, call)
        links = Candidates.suggest(video, call)
        if dropped != [], do: Logger.info("participants #{video.id}: dropped #{inspect(dropped)}")
        {:ok, _} = Videos.set_status(video, "speakers_suggested")
        {:ok, %{created: created + hints + links, dropped: dropped}}

      {:error, status, _call} ->
        {:error, status}
    end
  end

  # -- input

  # The first five minutes, plus the first few turns of every label that
  # does not speak in them (a formal opponent or timekeeper may first
  # speak much later); otherwise those labels could never pass Gate A.
  defp window_turns(transcript) do
    turns = Transcripts.turns_with_text(transcript.id, 100_000)
    {opening, rest} = Enum.split_with(turns, &(&1.start_ms < @window_ms))
    present = MapSet.new(opening, & &1.raw_label)

    late =
      rest
      |> Enum.reject(&(&1.kind == "backchannel" or MapSet.member?(present, &1.raw_label)))
      |> Enum.group_by(& &1.raw_label)
      |> Enum.flat_map(fn {_label, ts} -> Enum.take(ts, @late_turns) end)
      |> Enum.sort_by(& &1.start_ms)

    opening ++ late
  end

  defp messages(video, turns) do
    transcript =
      Enum.map_join(turns, "\n", fn t ->
        "[#{Topoi.Format.clock(t.start_ms)}] #{t.raw_label}: #{t.text}"
      end)

    [
      %{"role" => "system", "content" => system_prompt()},
      %{
        "role" => "user",
        "content" =>
          "Video title: #{video.title || "(none)"}\nChannel: #{video.channel_name || "(none)"}\n\nFirst five minutes, then the first lines of speakers who start later:\n#{transcript}"
      }
    ]
  end

  defp system_prompt do
    """
    You label the speakers in a recorded public debate. Speaker labels come from automatic diarization and are arbitrary.

    For every speaker label, report:
    - role: host (owns the stream or show), guest, moderator (runs a formal debate without arguing), or opponent (a formal debater who is not the host).
    - stated_name: the proper name or handle this speaker goes by, exactly as said in the transcript, title, or channel. Never a description ("proud atheist" is not a name). Empty if nobody states one.
    - name_quote: a verbatim excerpt (5 to 25 words) that shows the name. Empty if stated_name is empty.
    - role_quote: a verbatim excerpt (5 to 25 words) that shows the role.
    - position: the side this speaker argues in this debate, from the allowed list. Use undeclared if no side is stated.
    - position_quote: a verbatim excerpt that shows the side. Empty only for undeclared.
    - merge_with: another label if this label is the same person (diarization sometimes splits one person), otherwise empty.
    - confidence: 0 to 1.

    Also report the debate format from the allowed list, with a verbatim format_quote from the title or transcript.

    Each quote must be one contiguous excerpt copied character for character from a single line you were given (a transcript line, or the "Video title:" or "Channel:" line). Do not join excerpts with "..." and do not paraphrase. Do not guess names that are not stated. Do not describe anyone's character.
    """
  end

  defp schema(labels, positions) do
    quote_field = %{"type" => "string"}

    speaker = %{
      "type" => "object",
      "additionalProperties" => false,
      "required" =>
        ~w(raw_label role stated_name name_quote role_quote position position_quote merge_with confidence),
      "properties" => %{
        "raw_label" => %{"type" => "string", "enum" => labels},
        "role" => %{"type" => "string", "enum" => @roles},
        "stated_name" => %{"type" => "string"},
        "name_quote" => quote_field,
        "role_quote" => quote_field,
        "position" => %{"type" => "string", "enum" => positions},
        "position_quote" => quote_field,
        "merge_with" => %{"type" => "string", "enum" => ["" | labels]},
        "confidence" => %{"type" => "number"}
      }
    }

    %{
      "name" => "participants",
      "schema" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["speakers", "format", "format_quote"],
        "properties" => %{
          "speakers" => %{"type" => "array", "items" => speaker},
          "format" => %{"type" => "string", "enum" => @formats},
          "format_quote" => quote_field
        }
      }
    }
  end

  # -- output

  defp build(parsed, video, turns, corpus, positions, call) do
    debaters = Debaters.list_debaters()
    base = %{video_id: video.id, source: "model", llm_call_id: call.id}

    speaker_results =
      Enum.flat_map(parsed["speakers"] || [], fn sp ->
        label = sp["raw_label"]
        confidence = sp["confidence"]

        identity =
          with {:ok, quote, ms} <- evidence(sp["name_quote"], sp["role_quote"], turns, corpus) do
            {:create,
             Map.merge(base, %{
               kind: "identity",
               raw_label: label,
               value: sp["role"],
               stated_name: blank_to_nil(sp["stated_name"]),
               debater_id: link_debater(sp, debaters),
               evidence_quote: quote,
               evidence_ms: ms,
               confidence: confidence
             })}
          else
            {:drop, why} -> {:drop, "#{label} identity: #{why}"}
          end

        position =
          cond do
            sp["position"] not in positions ->
              {:drop, "#{label} position not in vocabulary"}

            sp["position"] == "undeclared" ->
              {:create,
               Map.merge(base, %{
                 kind: "position",
                 raw_label: label,
                 value: "undeclared",
                 confidence: confidence
               })}

            true ->
              case locate(sp["position_quote"], turns, corpus) do
                {:ok, quote, ms} ->
                  {:create,
                   Map.merge(base, %{
                     kind: "position",
                     raw_label: label,
                     value: sp["position"],
                     evidence_quote: quote,
                     evidence_ms: ms,
                     confidence: confidence
                   })}

                :not_found ->
                  {:drop, "#{label} position: quote not found"}
              end
          end

        merge =
          case sp["merge_with"] do
            other when other in [nil, "", label] ->
              nil

            other ->
              {:create,
               Map.merge(base, %{
                 kind: "merge",
                 raw_label: label,
                 merge_with_label: other,
                 evidence_quote: blank_to_nil(sp["role_quote"]),
                 confidence: confidence
               })}
          end

        Enum.reject([identity, position, merge], &is_nil/1)
      end)

    format =
      case locate(parsed["format_quote"], turns, corpus) do
        {:ok, quote, ms} ->
          {:create,
           Map.merge(base, %{
             kind: "format",
             value: parsed["format"],
             evidence_quote: quote,
             evidence_ms: ms
           })}

        :not_found ->
          {:drop, "format: quote not found"}
      end

    Enum.reduce([format | speaker_results], {0, []}, fn
      {:create, attrs}, {n, dropped} ->
        case Review.suggest(attrs) do
          {:ok, _} -> {n + 1, dropped}
          :already_decided -> {n, dropped}
          {:error, cs} -> {n, ["invalid #{attrs.kind}: #{inspect(cs.errors)}" | dropped]}
        end

      {:drop, why}, {n, dropped} ->
        {n, [why | dropped]}
    end)
    |> then(fn {n, dropped} -> {n, Enum.reverse(dropped)} end)
  end

  # Prefer the name quote; fall back to the role quote.
  defp evidence(name_quote, role_quote, turns, corpus) do
    case locate(name_quote, turns, corpus) do
      {:ok, q, ms} ->
        {:ok, q, ms}

      :not_found ->
        case locate(role_quote, turns, corpus) do
          {:ok, q, ms} -> {:ok, q, ms}
          :not_found -> {:drop, "no quote found in the transcript, title, or channel"}
        end
    end
  end

  @doc false
  # Finds a quote in the window's turns (returning the turn's start) or in
  # the title/channel lines (no time). Matching ignores case, punctuation,
  # and spacing, because ASR punctuation varies. A quote stitched from
  # several excerpts with "..." counts only if every excerpt is found.
  def locate(quote, turns, corpus) when is_binary(quote) do
    fragments =
      quote
      |> String.split(~r/\.{3}|…/u)
      |> Enum.map(&normalize/1)
      |> Enum.reject(&(String.length(&1) < 3))

    found = Enum.map(fragments, &find_fragment(&1, turns, corpus))

    cond do
      fragments == [] ->
        :not_found

      Enum.any?(found, &(&1 == :not_found)) ->
        :not_found

      true ->
        {:ok, String.trim(quote),
         found |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1) |> Enum.min(fn -> nil end)}
    end
  end

  def locate(_, _, _), do: :not_found

  defp find_fragment(needle, turns, corpus) do
    cond do
      turn = Enum.find(turns, &String.contains?(normalize(&1.text), needle)) ->
        {:found, turn.start_ms}

      String.contains?(corpus, needle) ->
        {:found, nil}

      true ->
        :not_found
    end
  end

  # The header lines exactly as the model saw them.
  defp corpus(video, _turns),
    do:
      normalize(
        "Video title: #{video.title || "(none)"}\nChannel: #{video.channel_name || "(none)"}"
      )

  defp normalize(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
  end

  @doc false
  # Code, not the model, links a stated name to a debater record.
  def match_debater(name, debaters) when is_binary(name) and name != "" do
    key = squash(name)

    Enum.find_value(debaters, fn d ->
      if Enum.any?([d.name, d.slug | d.handles], &(squash(&1) == key)), do: d.id
    end)
  end

  def match_debater(_, _), do: nil

  # A quote that merely mentions a handle may be about someone else (the
  # moderator introducing a debater), so quote matching applies only when
  # the model claims a name for this speaker.
  defp link_debater(%{"stated_name" => name} = sp, debaters)
       when is_binary(name) and name != "" do
    match_debater(name, debaters) || mentioned_debater(sp["name_quote"], debaters)
  end

  defp link_debater(_sp, _debaters), do: nil

  @doc false
  # A debater whose name or handle appears inside the name quote, e.g.
  # "Noah Beeser, AKA Jesusandwhatnot". Keys shorter than 6 characters
  # are ignored so short handles cannot match by accident.
  def mentioned_debater(quote, debaters) when is_binary(quote) and quote != "" do
    hay = squash(quote)

    Enum.find_value(debaters, fn d ->
      keys = [d.name | d.handles] |> Enum.map(&squash/1) |> Enum.filter(&(String.length(&1) >= 6))
      if Enum.any?(keys, &String.contains?(hay, &1)), do: d.id
    end)
  end

  def mentioned_debater(_, _), do: nil

  defp squash(s), do: s |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "")

  defp blank_to_nil(s) when s in [nil, ""], do: nil
  defp blank_to_nil(s), do: s
end
