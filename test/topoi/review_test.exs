defmodule Topoi.ReviewTest do
  use Topoi.DataCase, async: true

  import Topoi.AccountsFixtures
  import Topoi.IngestFixtures

  alias Topoi.{Review, Videos}

  setup do
    video = video_fixture()
    Videos.ensure_participants(video, ["speaker_0", "speaker_1", "speaker_4"])
    %{video: video, user: user_fixture() |> make_admin(), debater: debater_fixture()}
  end

  defp suggest(video, attrs) do
    {:ok, s} = Review.create_suggestion(Map.merge(%{video_id: video.id, source: "model"}, attrs))
    s
  end

  defp participant(video, label),
    do: Repo.get_by!(Topoi.Videos.Participant, video_id: video.id, raw_label: label)

  test "positions are seeded" do
    assert ~w(agnostic atheist deist theist undeclared) == Enum.sort(Review.position_slugs())
  end

  test "suggestions validate their kind" do
    assert {:error, cs} =
             Review.create_suggestion(%{
               video_id: Ecto.UUID.generate(),
               kind: "identity",
               source: "model",
               raw_label: "speaker_0",
               value: "boss"
             })

    assert errors_on(cs).value != []
  end

  test "a confirmed identity sets the participant; a rejection needs a reason", %{
    video: v,
    user: u,
    debater: d
  } do
    s =
      suggest(v, %{
        kind: "identity",
        raw_label: "speaker_1",
        value: "guest",
        stated_name: "Jesus",
        debater_id: d.id,
        evidence_quote: "I'm a Thomist"
      })

    assert {:error, cs} = Review.decide(s, "rejected", nil, u)
    assert errors_on(cs).reason == ["say why it is wrong"]

    assert {:ok, _} = Review.decide(s, "confirmed", nil, u)
    p = participant(v, "speaker_1")
    assert {p.role, p.debater_id, p.evidence_quote} == {"guest", d.id, "I'm a Thomist"}

    assert {:error, cs} = Review.decide(s, "confirmed", nil, u)
    assert "has already been decided" in errors_on(cs).suggestion_id
  end

  test "a rejected suggestion changes nothing", %{video: v, user: u} do
    s =
      suggest(v, %{
        kind: "position",
        raw_label: "speaker_0",
        value: "atheist",
        evidence_quote: "proud atheist"
      })

    assert {:ok, _} = Review.decide(s, "rejected", "Quote is the opponent's", u)
    assert participant(v, "speaker_0").position == nil
  end

  test "a confirmed merge puts two labels in one group with one identity", %{
    video: v,
    user: u,
    debater: d
  } do
    id = suggest(v, %{kind: "identity", raw_label: "speaker_1", value: "guest", debater_id: d.id})
    {:ok, _} = Review.decide(id, "confirmed", nil, u)

    merge =
      suggest(v, %{
        kind: "merge",
        raw_label: "speaker_4",
        merge_with_label: "speaker_1",
        source: "code"
      })

    {:ok, _} = Review.decide(merge, "confirmed", nil, u)

    s1 = participant(v, "speaker_1")
    s4 = participant(v, "speaker_4")
    assert s1.participant_id == s4.participant_id
    assert s4.debater_id == d.id
  end

  test "Gate A completes only when every label is settled and nothing is pending", %{
    video: v,
    user: u,
    debater: d
  } do
    a = suggest(v, %{kind: "identity", raw_label: "speaker_0", value: "host"})
    b = suggest(v, %{kind: "identity", raw_label: "speaker_1", value: "guest", debater_id: d.id})

    m =
      suggest(v, %{
        kind: "merge",
        raw_label: "speaker_4",
        merge_with_label: "speaker_1",
        source: "code"
      })

    f = suggest(v, %{kind: "format", value: "youtube_live"})

    for s <- [a, b, m], do: {:ok, _} = Review.decide(s, "confirmed", nil, u)
    assert Videos.get_video!(v.id).status == "submitted"
    assert Review.pending_count(v.id) == 1

    {:ok, _} = Review.decide(f, "confirmed", nil, u)
    video = Videos.get_video!(v.id)
    assert video.status == "speakers_confirmed"
    assert video.format == "youtube_live"
    assert participant(v, "speaker_0").confirmed_by_user
  end

  test "confirming a debater link settles its alternatives", %{video: v, user: u, debater: d} do
    model0 = suggest(v, %{kind: "identity", raw_label: "speaker_0", value: "guest"})

    link0 =
      suggest(v, %{
        kind: "identity",
        raw_label: "speaker_0",
        value: "guest",
        debater_id: d.id,
        source: "code"
      })

    link1 =
      suggest(v, %{
        kind: "identity",
        raw_label: "speaker_1",
        value: "host",
        debater_id: d.id,
        source: "code"
      })

    model1 = suggest(v, %{kind: "identity", raw_label: "speaker_1", value: "host"})

    {:ok, _} = Review.decide(link0, "confirmed", nil, u)

    outcome = fn s -> Review.get_suggestion!(s.id).decision end

    assert %{outcome: "rejected", reason: "Another identity was confirmed for speaker_0"} =
             outcome.(model0)

    assert %{outcome: "rejected", reason: reason} = outcome.(link1)
    assert reason =~ "was confirmed as speaker_0"
    assert outcome.(model1) == nil
  end

  test "one debater cannot be confirmed as two different people", %{video: v, user: u, debater: d} do
    a = suggest(v, %{kind: "identity", raw_label: "speaker_0", value: "guest", debater_id: d.id})
    {:ok, _} = Review.decide(a, "confirmed", nil, u)

    b =
      suggest(v, %{
        kind: "identity",
        raw_label: "speaker_1",
        value: "guest",
        debater_id: d.id,
        source: "code"
      })

    assert {:error, :debater_already_confirmed} = Review.decide(b, "confirmed", nil, u)
    assert Review.get_suggestion!(b.id).decision == nil

    # A merged label is the same person: it takes the identity through the
    # merge, and its own identity cannot be confirmed separately.
    m =
      suggest(v, %{
        kind: "merge",
        raw_label: "speaker_4",
        merge_with_label: "speaker_0",
        source: "code"
      })

    {:ok, _} = Review.decide(m, "confirmed", nil, u)
    assert participant(v, "speaker_4").debater_id == d.id

    c =
      suggest(v, %{
        kind: "identity",
        raw_label: "speaker_4",
        value: "guest",
        debater_id: d.id,
        source: "code"
      })

    assert {:error, :merged} = Review.decide(c, "confirmed", nil, u)
  end

  test "each slot takes one confirmed answer", %{video: v, user: u} do
    moderator = suggest(v, %{kind: "identity", raw_label: "speaker_0", value: "moderator"})
    host = suggest(v, %{kind: "identity", raw_label: "speaker_0", value: "host"})
    f1 = suggest(v, %{kind: "format", value: "moderated_formal"})
    f2 = suggest(v, %{kind: "format", value: "podcast"})

    {:ok, _} = Review.decide(moderator, "confirmed", nil, u)

    assert %{outcome: "rejected", reason: "Another identity was confirmed for speaker_0"} =
             Review.get_suggestion!(host.id).decision

    {:ok, _} = Review.decide(f1, "confirmed", nil, u)

    assert %{outcome: "rejected", reason: "Another format was confirmed"} =
             Review.get_suggestion!(f2.id).decision

    {:ok, _} = Review.reconsider(Review.get_suggestion!(f2.id))

    [copy] =
      Review.suggestions_by_label(v.id)[nil]
      |> Enum.filter(&(&1.value == "podcast" and is_nil(&1.decision)))

    assert {:error, :slot_taken} = Review.decide(copy, "confirmed", nil, u)
  end

  test "a confirmed merge settles the merged label and carries the identity", %{
    video: v,
    user: u,
    debater: d
  } do
    own_id = suggest(v, %{kind: "identity", raw_label: "speaker_4", value: "guest"})

    own_pos =
      suggest(v, %{kind: "position", raw_label: "speaker_4", value: "theist", evidence_quote: "q"})

    merge =
      suggest(v, %{
        kind: "merge",
        raw_label: "speaker_4",
        merge_with_label: "speaker_1",
        source: "code"
      })

    {:ok, _} = Review.decide(merge, "confirmed", nil, u)

    assert %{reason: "speaker_4 was merged into speaker_1"} =
             Review.get_suggestion!(own_id.id).decision

    assert %{reason: "speaker_4 was merged into speaker_1"} =
             Review.get_suggestion!(own_pos.id).decision

    refute "speaker_4" in Review.unsettled_labels(v.id)

    late = suggest(v, %{kind: "identity", raw_label: "speaker_4", value: "host"})
    assert {:error, :merged} = Review.decide(late, "confirmed", nil, u)

    id1 =
      suggest(v, %{kind: "identity", raw_label: "speaker_1", value: "opponent", debater_id: d.id})

    {:ok, _} = Review.decide(id1, "confirmed", nil, u)
    assert participant(v, "speaker_4").debater_id == d.id
    assert participant(v, "speaker_4").role == "opponent"
  end

  test "conflicts/1 reports old double confirmations; start_over keeps history and resets", %{
    video: v,
    user: u
  } do
    a = suggest(v, %{kind: "format", value: "moderated_formal"})
    b = suggest(v, %{kind: "format", value: "podcast"})

    # Simulate decisions made before the one-answer rule existed.
    for s <- [a, b],
        do:
          Repo.insert!(%Topoi.Review.Decision{
            suggestion_id: s.id,
            outcome: "confirmed",
            decided_by_id: u.id
          })

    assert [{"format", nil, values}] = Review.conflicts(v.id)
    assert Enum.sort(values) == ["moderated_formal", "podcast"]

    {:ok, _} = Review.start_over(v.id)
    assert Review.suggestions_by_label(v.id) == %{}
    assert Review.conflicts(v.id) == []
    assert Repo.aggregate(Topoi.Review.Suggestion, :count) == 2
    assert Videos.get_video!(v.id).status == "normalized"
  end

  test "suggest/1 never re-asks a decided question", %{video: v, user: u, debater: d} do
    attrs = %{
      video_id: v.id,
      source: "model",
      kind: "identity",
      raw_label: "speaker_1",
      value: "guest",
      debater_id: d.id
    }

    {:ok, s} = Review.suggest(attrs)
    {:ok, _} = Review.decide(s, "rejected", "No", u)

    assert :already_decided = Review.suggest(Map.put(attrs, :stated_name, "different wording"))
    assert {:ok, _} = Review.suggest(Map.put(attrs, :value, "host"))
  end

  test "unsettled_labels/1 lists labels without a confirmed identity or merge", %{
    video: v,
    user: u
  } do
    assert Review.unsettled_labels(v.id) == ["speaker_0", "speaker_1", "speaker_4"]
    s = suggest(v, %{kind: "identity", raw_label: "speaker_0", value: "host"})
    {:ok, _} = Review.decide(s, "confirmed", nil, u)
    assert Review.unsettled_labels(v.id) == ["speaker_1", "speaker_4"]
  end

  test "clear_pending/1 removes only undecided suggestions", %{video: v, user: u} do
    decided = suggest(v, %{kind: "identity", raw_label: "speaker_0", value: "host"})
    {:ok, _} = Review.decide(decided, "confirmed", nil, u)
    suggest(v, %{kind: "identity", raw_label: "speaker_1", value: "guest"})

    Review.clear_pending(v.id)
    assert [%{id: id}] = Review.suggestions_by_label(v.id) |> Map.values() |> List.flatten()
    assert id == decided.id
  end
end
