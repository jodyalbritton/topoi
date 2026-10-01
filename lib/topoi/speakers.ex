defmodule Topoi.Speakers do
  @moduledoc """
  Gate A as a form (PRD §13): for each speaker label, who it is, their
  role, and their side; for the debate, its format, channel of record,
  and publish date.

  Suggestions (`Topoi.Review`) pre-fill the form and explain themselves;
  the person confirming can keep or change any answer. Speaker labels are
  the one place where a person may type a label directly (a name for
  someone without a debater record), because who is talking is a plain
  fact and the record must not wait on the model (PRD §6 note).

  "Who" answers are encoded as `"debater:<id>"`, `"name"` (with a typed
  name), `"same:<label>"` (the same person as another label), or
  `"unknown"` (cannot tell).
  """
  import Ecto.Query, warn: false

  alias Topoi.{Debaters, Repo, Review, Videos}
  alias Topoi.Videos.{Participant, Video}

  @roles ~w(host guest moderator opponent)
  @formats ~w(moderated_formal youtube_live tiktok_live podcast monologue)
  @channels ~w(debater opponent third_party unknown)

  def roles, do: @roles
  def formats, do: @formats
  def channels, do: @channels

  @doc """
  The form's starting values and the hints behind them.

  Returns `%{speakers: [speaker], facts: facts}` where each speaker is
  `%{label, who, name, role, position, hints}` and `hints` maps a field
  to a one-line reason. Confirmed answers win over suggestions.
  """
  def form(video_id) do
    video = Videos.get_video!(video_id)

    participants =
      Repo.all(from p in Participant, where: p.video_id == ^video_id, order_by: p.raw_label)

    by_label = Review.suggestions_by_label(video_id)
    groups = Map.new(participants, &{&1.id, &1.raw_label})

    speakers =
      Enum.map(participants, fn p ->
        if p.confirmed_by_user,
          do: from_record(p, groups),
          else: from_suggestions(p.raw_label, Map.get(by_label, p.raw_label, []))
      end)

    %{speakers: speakers, facts: facts(video, Map.get(by_label, nil, []))}
  end

  defp from_record(p, groups) do
    root = p.participant_id && Map.get(groups, p.participant_id)

    who =
      cond do
        root && root != p.raw_label -> "same:" <> root
        p.unidentified -> "unknown"
        p.debater_id -> "debater:" <> p.debater_id
        p.display_name -> "name"
        true -> "unknown"
      end

    %{
      label: p.raw_label,
      who: who,
      name: p.display_name,
      role: p.role,
      position: p.position || "undeclared",
      hints: %{}
    }
  end

  # Pre-fill from what was suggested, most reliable first: the rule's
  # handoff merge, a debater link, the model's merge (only without a
  # link; the model sometimes points a merge the wrong way), then a
  # stated name. Role and side come from the model.
  defp from_suggestions(label, suggestions) do
    live = Enum.reject(suggestions, &(&1.decision && &1.decision.outcome == "rejected"))
    merges = Enum.filter(live, &(&1.kind == "merge"))
    rule_merge = Enum.find(merges, &(&1.source == "code"))
    model_merge = Enum.find(merges, &(&1.source == "model"))
    identities = Enum.filter(live, &(&1.kind == "identity"))
    linked = Enum.find(identities, & &1.debater_id)
    named = Enum.find(identities, &(&1.stated_name not in [nil, ""]))
    role_s = Enum.find(identities, &(&1.source == "model")) || List.first(identities)
    position = Enum.find(live, &(&1.kind == "position"))

    {who, name, who_hint} =
      cond do
        rule_merge -> {"same:" <> rule_merge.merge_with_label, nil, hint(rule_merge)}
        linked -> {"debater:" <> linked.debater_id, nil, hint(linked)}
        model_merge -> {"same:" <> model_merge.merge_with_label, nil, hint(model_merge)}
        named -> {"name", named.stated_name, hint(named)}
        true -> {nil, nil, nil}
      end

    %{
      label: label,
      who: who,
      name: name,
      role: role_s && role_s.value,
      position: (position && position.value) || "undeclared",
      hints:
        %{who: who_hint, role: role_s && hint(role_s), position: position && hint(position)}
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
    }
  end

  defp facts(video, suggestions) do
    live = Enum.reject(suggestions, &(&1.decision && &1.decision.outcome == "rejected"))
    format = Enum.find(live, &(&1.kind == "format"))
    channel = Enum.find(live, &(&1.kind == "channel_of_record"))

    %{
      format: video.format || (format && format.value),
      channel_of_record:
        if(video.channel_of_record != "unknown",
          do: video.channel_of_record,
          else: (channel && channel.value) || "unknown"
        ),
      published_on: video.published_at && Date.to_iso8601(DateTime.to_date(video.published_at)),
      hints:
        %{format: format && hint(format), channel_of_record: channel && hint(channel)}
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
    }
  end

  # One line: the source and its evidence.
  defp hint(s) do
    source = if s.source == "code", do: "rule", else: "model"
    evidence = s.evidence_quote && String.slice(s.evidence_quote, 0, 160)
    if evidence, do: "Suggested by #{source}: #{evidence}", else: "Suggested by #{source}"
  end

  @doc """
  Checks and saves the form. `params` is `%{"speakers" => %{label =>
  %{"who", "name", "role", "position"}}, "facts" => %{"format",
  "channel_of_record", "published_on"}}`.

  Returns `{:ok, video}` or `{:error, errors}` where `errors` maps a
  label (or `:facts`) to a message saying what to fix.
  """
  def confirm(video_id, params, user) do
    participants = Repo.all(from p in Participant, where: p.video_id == ^video_id)
    labels = Enum.map(participants, & &1.raw_label)
    answers = Map.get(params, "speakers", %{})
    facts = Map.get(params, "facts", %{})

    with :ok <- check(labels, answers, facts) do
      write(video_id, participants, answers, facts, user)
    end
  end

  defp check(labels, answers, facts) do
    debaters = Debaters.list_debaters() |> Map.new(&{&1.id, &1.name})

    errors =
      Enum.reduce(labels, %{}, fn label, acc ->
        a = Map.get(answers, label, %{})

        case check_one(label, a, labels, answers) do
          :ok -> acc
          {:error, msg} -> Map.put(acc, label, msg)
        end
      end)

    errors =
      answers
      |> Enum.flat_map(fn {label, a} ->
        case a["who"] do
          "debater:" <> id -> [{id, label}]
          _ -> []
        end
      end)
      |> Enum.group_by(fn {id, _} -> id end, fn {_, label} -> label end)
      |> Enum.reduce(errors, fn
        {_id, [_]}, acc ->
          acc

        {id, [first | rest]}, acc ->
          Enum.reduce(rest, acc, fn label, acc ->
            Map.put_new(
              acc,
              label,
              "#{Map.get(debaters, id, "That debater")} is already #{first}. If this is the same person, choose “Same person as #{first}”."
            )
          end)
      end)

    errors =
      cond do
        facts["format"] not in @formats ->
          Map.put(errors, :facts, "Choose the debate's format.")

        facts["channel_of_record"] not in @channels ->
          Map.put(errors, :facts, "Choose the channel of record.")

        facts["published_on"] not in [nil, ""] and
            match?({:error, _}, Date.from_iso8601(facts["published_on"])) ->
          Map.put(errors, :facts, "The publish date is not a date.")

        true ->
          errors
      end

    if errors == %{}, do: :ok, else: {:error, errors}
  end

  defp check_one(label, a, labels, answers) do
    case a["who"] do
      w when w in [nil, ""] ->
        {:error, "Choose who this is."}

      "name" ->
        cond do
          String.trim(a["name"] || "") == "" -> {:error, "Type the name this person goes by."}
          a["role"] not in @roles -> {:error, "Choose a role."}
          true -> :ok
        end

      "unknown" ->
        :ok

      "same:" <> other ->
        cond do
          other == label ->
            {:error, "A speaker cannot be the same person as itself."}

          other not in labels ->
            {:error, "Choose a speaker from this debate."}

          root(other, answers, [label]) == :cycle ->
            {:error, "These speakers point at each other. Pick one of them as the person."}

          true ->
            :ok
        end

      "debater:" <> _ ->
        if a["role"] in @roles, do: :ok, else: {:error, "Choose a role."}

      _ ->
        {:error, "Choose who this is."}
    end
  end

  # Follows "same as" answers to the label that holds the identity.
  defp root(label, answers, seen) do
    case get_in(answers, [label, "who"]) do
      "same:" <> next -> if next in seen, do: :cycle, else: root(next, answers, [label | seen])
      _ -> label
    end
  end

  defp write(video_id, participants, answers, facts, user) do
    now = DateTime.utc_now(:second)
    by_label = Map.new(participants, &{&1.raw_label, &1})

    Repo.transaction(fn ->
      # Identities first, for every label that is its own person.
      for p <- participants,
          not String.starts_with?(get_in(answers, [p.raw_label, "who"]) || "", "same:") do
        a = Map.get(answers, p.raw_label, %{})

        {debater_id, name, unidentified} =
          case a["who"] do
            "debater:" <> id -> {id, nil, false}
            "name" -> {nil, String.trim(a["name"]), false}
            _ -> {nil, nil, true}
          end

        p
        |> Ecto.Changeset.change(
          participant_id: nil,
          debater_id: debater_id,
          display_name: name,
          unidentified: unidentified,
          role: if(a["role"] in @roles, do: a["role"]),
          position: a["position"] || "undeclared",
          confirmed_by_user: true,
          confirmed_by_id: user.id,
          confirmed_at: now
        )
        |> Repo.update!()
      end

      # Then "same as" labels take the identity of the label they point at.
      for p <- participants,
          String.starts_with?(get_in(answers, [p.raw_label, "who"]) || "", "same:") do
        root = Repo.get!(Participant, by_label[root(p.raw_label, answers, [])].id)
        group = root.participant_id || root.id
        root |> Ecto.Changeset.change(participant_id: group) |> Repo.update!()

        p
        |> Ecto.Changeset.change(
          participant_id: group,
          debater_id: root.debater_id,
          display_name: root.display_name,
          unidentified: root.unidentified,
          role: root.role,
          position: root.position,
          confirmed_by_user: true,
          confirmed_by_id: user.id,
          confirmed_at: now
        )
        |> Repo.update!()
      end

      published_at =
        case Date.from_iso8601(facts["published_on"] || "") do
          {:ok, d} -> DateTime.new!(d, ~T[00:00:00])
          _ -> nil
        end

      video = Repo.get!(Video, video_id)

      video
      |> Video.review_changeset(%{
        format: facts["format"],
        channel_of_record: facts["channel_of_record"],
        published_at: published_at || video.published_at
      })
      |> Repo.update!()
      |> Video.status_changeset("speakers_confirmed")
      |> Repo.update!()
    end)
    |> tap(fn _ -> Videos.notify(video_id) end)
  end
end
