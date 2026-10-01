defmodule Topoi.Review do
  @moduledoc """
  Suggest, then confirm (PRD §6). Suggestions carry evidence; a human
  confirms or rejects each one, and only a confirmation changes the
  record. Gate A (§13) is complete for a video when every suggestion is
  decided and every speaker label has a confirmed identity or merge.
  """
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Topoi.Repo
  alias Topoi.Review.{Decision, Position, Suggestion}
  alias Topoi.Videos
  alias Topoi.Videos.{Participant, Video}

  ## Positions

  def list_positions, do: Repo.all(from p in Position, order_by: p.name)
  def position_slugs, do: Repo.all(from p in Position, select: p.slug)

  ## Suggestions

  # Live suggestions: not superseded by "start over".
  defp live, do: from(s in Suggestion, where: is_nil(s.superseded_at))

  def create_suggestion(attrs), do: %Suggestion{} |> Suggestion.changeset(attrs) |> Repo.insert()

  @doc """
  Like `create_suggestion/1`, but skips a suggestion that makes the same
  claim as one already decided (same kind, label, value, debater, and
  merge target), so a re-run never asks the same question twice.
  Returns `{:ok, suggestion}` or `:already_decided`.
  """
  def suggest(attrs) do
    attrs = Map.new(attrs)

    decided =
      from(s in live(),
        join: d in assoc(s, :decision),
        where: s.video_id == ^attrs.video_id and s.kind == ^attrs.kind
      )
      |> Repo.all()
      |> Enum.any?(&same_claim?(&1, attrs))

    if decided, do: :already_decided, else: create_suggestion(attrs)
  end

  defp same_claim?(s, attrs) do
    s.raw_label == Map.get(attrs, :raw_label) and s.value == Map.get(attrs, :value) and
      s.debater_id == Map.get(attrs, :debater_id) and
      s.merge_with_label == Map.get(attrs, :merge_with_label)
  end

  @doc """
  Re-opens a rejected suggestion as a new pending copy. The rejection
  stays as history; the copy is decided like any other suggestion.
  """
  def reconsider(%Suggestion{decision: %{outcome: "rejected"}} = s) do
    s
    |> Map.take(~w(video_id raw_label kind value stated_name debater_id merge_with_label
                   evidence_quote evidence_ms confidence source llm_call_id)a)
    |> create_suggestion()
    |> tap(fn _ -> Videos.notify(s.video_id) end)
  end

  def reconsider(_), do: {:error, :not_rejected}

  @doc """
  Starts Gate A over for a video: every live suggestion (and so its
  decision) is marked superseded and kept as history, and what the
  confirmations wrote is cleared. The caller then asks for new
  suggestions.
  """
  def start_over(video_id) do
    now = DateTime.utc_now(:second)

    Repo.transaction(fn ->
      Repo.update_all(from(s in live(), where: s.video_id == ^video_id),
        set: [superseded_at: now]
      )

      Repo.update_all(from(p in Participant, where: p.video_id == ^video_id),
        set: [
          participant_id: nil,
          role: nil,
          position: nil,
          debater_id: nil,
          confidence: nil,
          evidence_quote: nil,
          confirmed_by_user: false
        ]
      )

      video = Repo.get!(Video, video_id)

      {:ok, _} =
        video
        |> Ecto.Changeset.change(format: nil, channel_of_record: "unknown")
        |> Repo.update()

      {:ok, _} = video |> Video.status_changeset("normalized") |> Repo.update()
    end)
    |> tap(fn _ -> Videos.notify(video_id) end)
  end

  @doc """
  Labels that keep Gate A open: no confirmed identity and no confirmed
  merge. Empty when the gate can complete.
  """
  def unsettled_labels(video_id) do
    by_label = suggestions_by_label(video_id) |> Map.delete(nil)

    video_id
    |> labels()
    |> Enum.reject(fn label ->
      Enum.any?(Map.get(by_label, label, []), &(&1.kind in ~w(identity merge) and confirmed?(&1)))
    end)
  end

  @doc """
  Slots holding more than one confirmed answer (left over from before
  the one-answer rule): `[{kind, label_or_nil, [values]}]`.
  """
  def conflicts(video_id) do
    suggestions_by_label(video_id)
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(&confirmed?/1)
    |> Enum.group_by(&slot/1)
    |> Enum.filter(fn {_slot, ss} -> length(Enum.uniq_by(ss, &claim_key/1)) > 1 end)
    |> Enum.map(fn {{kind, label}, ss} ->
      {kind, label, Enum.map(ss, &(&1.value || &1.merge_with_label))}
    end)
  end

  @doc "A video's live suggestions with their decisions, grouped by raw label (`nil` for video-level kinds)."
  def suggestions_by_label(video_id) do
    from(s in live(),
      where: s.video_id == ^video_id,
      order_by: [s.raw_label, s.kind, s.inserted_at],
      preload: [:decision, :debater]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.raw_label)
  end

  def get_suggestion!(id), do: Suggestion |> Repo.get!(id) |> Repo.preload([:decision, :debater])

  def pending_count(video_id) do
    Repo.aggregate(
      from(s in live(),
        left_join: d in assoc(s, :decision),
        where: s.video_id == ^video_id and is_nil(d.id)
      ),
      :count
    )
  end

  @doc """
  Clears a video's undecided suggestions before a fresh proposal, so a
  re-run never stacks duplicates. Decided ones stay as the record.
  """
  def clear_pending(video_id) do
    pending =
      from s in live(),
        left_join: d in assoc(s, :decision),
        where: s.video_id == ^video_id and is_nil(d.id),
        select: s.id

    Repo.delete_all(from s in Suggestion, where: s.id in subquery(pending))
  end

  ## Decisions

  @doc """
  Records a decision. A confirmation applies the suggestion to the
  record and settles its alternatives; a rejection needs a reason and
  changes nothing else. Each slot (a speaker's identity, position, or
  merge; the debate's format or channel of record) takes one confirmed
  answer. Returns `{:ok, decision}` or `{:error, reason}`.
  """
  def decide(%Suggestion{} = suggestion, outcome, reason, user) do
    confirm? = outcome == "confirmed"

    Multi.new()
    |> Multi.run(:guard, fn _repo, _ -> if confirm?, do: guard(suggestion), else: {:ok, :skip} end)
    |> Multi.insert(
      :decision,
      Decision.changeset(%Decision{}, %{
        suggestion_id: suggestion.id,
        outcome: outcome,
        reason: reason,
        decided_by_id: user.id
      })
    )
    |> Multi.run(:apply, fn _repo, _ ->
      if confirm?, do: apply_suggestion(suggestion), else: {:ok, :rejected}
    end)
    |> Multi.run(:settle, fn _repo, _ ->
      if confirm?, do: settle_alternatives(suggestion, user), else: {:ok, 0}
    end)
    |> Multi.run(:gate, fn _repo, _ -> {:ok, maybe_complete_gate_a(suggestion.video_id)} end)
    |> Repo.transaction()
    |> case do
      {:ok, %{decision: decision}} ->
        Videos.notify(suggestion.video_id)
        {:ok, decision}

      {:error, :decision, changeset, _} ->
        {:error, changeset}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  # -- slots

  defp slot(%Suggestion{kind: kind}) when kind in ~w(format channel_of_record), do: {kind, nil}
  defp slot(%Suggestion{kind: kind, raw_label: label}), do: {kind, label}

  defp claim_key(s), do: {s.value, s.debater_id, s.merge_with_label}

  defp confirmed?(%Suggestion{decision: %{outcome: "confirmed"}}), do: true
  defp confirmed?(_), do: false

  defp live_in_video(video_id) do
    from(s in live(), where: s.video_id == ^video_id, preload: [:decision, :debater])
    |> Repo.all()
  end

  # -- guards

  defp guard(%Suggestion{} = s) do
    others = live_in_video(s.video_id)

    cond do
      Enum.any?(
        others,
        &(&1.id != s.id and slot(&1) == slot(s) and confirmed?(&1) and
              claim_key(&1) != claim_key(s))
      ) ->
        {:error, :slot_taken}

      s.kind in ~w(identity position) and
          Enum.any?(
            others,
            &(&1.kind == "merge" and &1.raw_label == s.raw_label and confirmed?(&1))
          ) ->
        {:error, :merged}

      true ->
        check_one_person(s)
    end
  end

  # One debater is one person: a debater confirmed on one speaker cannot
  # be confirmed on another unless the two labels are merged.
  defp check_one_person(%Suggestion{kind: "identity", debater_id: d} = s) when is_binary(d) do
    me = participant!(s.video_id, s.raw_label)

    clash =
      Repo.one(
        from p in Participant,
          where: p.video_id == ^s.video_id and p.debater_id == ^d and p.raw_label != ^s.raw_label,
          limit: 1
      )

    if clash && !(me.participant_id && me.participant_id == clash.participant_id),
      do: {:error, :debater_already_confirmed},
      else: {:ok, :clear}
  end

  defp check_one_person(_), do: {:ok, :clear}

  # -- settling

  # A confirmation answers its alternatives, which are rejected with the
  # reason under the same reviewer:
  #   * other pending suggestions in the same slot;
  #   * for a debater link, that debater's pending links on other speakers;
  #   * for a merge, the merged label's pending identity and position.
  defp settle_alternatives(%Suggestion{} = s, user) do
    who = s.debater_id && Repo.get(Topoi.Debaters.Debater, s.debater_id)

    reasons =
      s.video_id
      |> live_in_video()
      |> Enum.filter(&(&1.id != s.id and is_nil(&1.decision)))
      |> Enum.flat_map(fn o ->
        cond do
          slot(o) == slot(s) ->
            [
              {o,
               "Another #{String.replace(s.kind, "_", " ")} was confirmed#{if s.raw_label, do: " for #{s.raw_label}"}"}
            ]

          s.kind == "identity" and who != nil and o.kind == "identity" and o.debater_id == who.id ->
            [{o, "#{who.name} was confirmed as #{s.raw_label}"}]

          s.kind == "merge" and o.raw_label == s.raw_label and o.kind in ~w(identity position) ->
            [{o, "#{s.raw_label} was merged into #{s.merge_with_label}"}]

          true ->
            []
        end
      end)

    Enum.each(reasons, fn {o, reason} ->
      Repo.insert!(
        Decision.changeset(%Decision{}, %{
          suggestion_id: o.id,
          outcome: "rejected",
          reason: reason,
          decided_by_id: user.id
        })
      )
    end)

    {:ok, length(reasons)}
  end

  # -- applying

  # An identity applies to the label and to every label merged with it.
  defp apply_suggestion(%Suggestion{kind: "identity"} = s) do
    update_group(s, %{
      role: s.value,
      debater_id: s.debater_id,
      evidence_quote: s.evidence_quote,
      confidence: s.confidence
    })
  end

  defp apply_suggestion(%Suggestion{kind: "position"} = s),
    do: update_group(s, %{position: s.value})

  defp apply_suggestion(%Suggestion{kind: "merge"} = s) do
    target = participant!(s.video_id, s.merge_with_label)
    group = target.participant_id || target.id

    {:ok, _} = target |> Ecto.Changeset.change(participant_id: group) |> Repo.update()

    s.video_id
    |> participant!(s.raw_label)
    |> Ecto.Changeset.change(
      participant_id: group,
      role: target.role,
      debater_id: target.debater_id,
      position: target.position
    )
    |> Repo.update()
  end

  defp apply_suggestion(%Suggestion{kind: kind} = s) when kind in ~w(format channel_of_record) do
    s.video_id
    |> then(&Repo.get!(Video, &1))
    |> Video.review_changeset(%{String.to_existing_atom(kind) => s.value})
    |> Repo.update()
  end

  defp update_group(%Suggestion{video_id: video_id, raw_label: label}, attrs) do
    me = participant!(video_id, label)
    {:ok, me} = me |> Ecto.Changeset.change(attrs) |> Repo.update()

    if me.participant_id do
      Repo.update_all(
        from(p in Participant,
          where: p.video_id == ^video_id and p.participant_id == ^me.participant_id
        ),
        set: Map.to_list(attrs)
      )
    end

    {:ok, me}
  end

  defp participant!(video_id, label),
    do: Repo.get_by!(Participant, video_id: video_id, raw_label: label)

  defp labels(video_id) do
    Repo.all(
      from p in Participant,
        where: p.video_id == ^video_id,
        select: p.raw_label,
        order_by: p.raw_label
    )
  end

  # Gate A completes when nothing is pending, no slot holds conflicting
  # answers, and every label has a confirmed identity or merge.
  defp maybe_complete_gate_a(video_id) do
    settled? =
      labels(video_id) != [] and pending_count(video_id) == 0 and
        unsettled_labels(video_id) == [] and conflicts(video_id) == []

    if settled? do
      Repo.update_all(from(p in Participant, where: p.video_id == ^video_id),
        set: [confirmed_by_user: true]
      )

      video = Repo.get!(Video, video_id)
      {:ok, _} = video |> Video.status_changeset("speakers_confirmed") |> Repo.update()
      :complete
    else
      :open
    end
  end
end
