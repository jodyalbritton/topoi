defmodule Topoi.SpeakersTest do
  use Topoi.DataCase, async: true

  import Topoi.AccountsFixtures
  import Topoi.IngestFixtures

  alias Topoi.{Review, Speakers, Videos}
  alias Topoi.Videos.Participant

  setup do
    video = video_fixture()
    Videos.ensure_participants(video, ["speaker_0", "speaker_1", "speaker_4"])

    %{
      video: video,
      user: user_fixture() |> make_admin(),
      jw: debater_fixture(%{name: "Jesus and Whatnot", slug: "jesus-and-whatnot"})
    }
  end

  defp suggest(v, attrs),
    do: {:ok, _} = Review.create_suggestion(Map.merge(%{video_id: v.id, source: "model"}, attrs))

  defp p(v, label), do: Repo.get_by!(Participant, video_id: v.id, raw_label: label)

  @facts %{
    "format" => "moderated_formal",
    "channel_of_record" => "debater",
    "published_on" => "2026-08-14"
  }

  test "pre-fills from suggestions: a merge, then a debater link, then a stated name", %{
    video: v,
    jw: jw
  } do
    suggest(v, %{
      kind: "identity",
      raw_label: "speaker_0",
      value: "moderator",
      evidence_quote: "Ladies and gentlemen"
    })

    suggest(v, %{
      kind: "identity",
      raw_label: "speaker_1",
      value: "opponent",
      stated_name: "Jesusandwhatnot",
      debater_id: jw.id,
      evidence_quote: "Jesusandwhatnot on the affirmative"
    })

    suggest(v, %{
      kind: "position",
      raw_label: "speaker_1",
      value: "theist",
      evidence_quote: "the Christian God does exist"
    })

    suggest(v, %{
      kind: "merge",
      raw_label: "speaker_4",
      merge_with_label: "speaker_1",
      source: "code",
      evidence_quote: "speaker_1 stops mid-sentence"
    })

    suggest(v, %{kind: "format", value: "moderated_formal", evidence_quote: "opening statements"})

    form = Speakers.form(v.id)
    by = Map.new(form.speakers, &{&1.label, &1})

    assert by["speaker_0"].who == nil
    assert by["speaker_0"].role == "moderator"
    assert by["speaker_1"].who == "debater:" <> jw.id
    assert by["speaker_1"].position == "theist"
    assert by["speaker_1"].hints.who =~ "Suggested by model: Jesusandwhatnot on the affirmative"
    assert by["speaker_4"].who == "same:speaker_1"
    assert by["speaker_4"].hints.who =~ "Suggested by rule"
    assert form.facts.format == "moderated_formal"
  end

  test "says what to fix", %{video: v, user: u, jw: jw} do
    answers = %{
      "speaker_0" => %{"who" => "", "role" => "", "position" => "undeclared"},
      "speaker_1" => %{"who" => "debater:" <> jw.id, "role" => "", "position" => "theist"},
      "speaker_4" => %{"who" => "debater:" <> jw.id, "role" => "guest", "position" => "theist"}
    }

    assert {:error, errors} = Speakers.confirm(v.id, %{"speakers" => answers, "facts" => %{}}, u)
    assert errors["speaker_0"] == "Choose who this is."
    assert errors["speaker_1"] == "Choose a role."
    assert errors["speaker_4"] =~ "Jesus and Whatnot is already speaker_1"
    assert errors[:facts] == "Choose the debate's format."
  end

  test "rejects a name left blank and labels pointing at each other", %{video: v, user: u} do
    answers = %{
      "speaker_0" => %{"who" => "name", "name" => " ", "role" => "moderator"},
      "speaker_1" => %{"who" => "same:speaker_4"},
      "speaker_4" => %{"who" => "same:speaker_1"}
    }

    assert {:error, errors} =
             Speakers.confirm(v.id, %{"speakers" => answers, "facts" => @facts}, u)

    assert errors["speaker_0"] == "Type the name this person goes by."
    assert errors["speaker_1"] =~ "point at each other"
  end

  test "saves identities, typed names, same-as groups, and the debate's facts", %{
    video: v,
    user: u,
    jw: jw
  } do
    answers = %{
      "speaker_0" => %{
        "who" => "name",
        "name" => "Moderator Mike",
        "role" => "moderator",
        "position" => "undeclared"
      },
      "speaker_1" => %{"who" => "debater:" <> jw.id, "role" => "opponent", "position" => "theist"},
      "speaker_4" => %{"who" => "same:speaker_1"}
    }

    assert {:ok, _} = Speakers.confirm(v.id, %{"speakers" => answers, "facts" => @facts}, u)

    assert p(v, "speaker_0").display_name == "Moderator Mike"
    s1 = p(v, "speaker_1")
    s4 = p(v, "speaker_4")
    assert {s1.debater_id, s1.role, s1.position} == {jw.id, "opponent", "theist"}
    assert s4.participant_id == s1.participant_id
    assert {s4.debater_id, s4.role, s4.position} == {jw.id, "opponent", "theist"}
    assert s4.confirmed_by_id == u.id

    video = Videos.get_video!(v.id)

    assert {video.status, video.format, video.channel_of_record} ==
             {"speakers_confirmed", "moderated_formal", "debater"}

    assert video.published_at == ~U[2026-08-14 00:00:00Z]

    # Re-opening the form shows the saved answers.
    by = Map.new(Speakers.form(v.id).speakers, &{&1.label, &1})
    assert by["speaker_4"].who == "same:speaker_1"
    assert by["speaker_0"].who == "name"
  end

  test "\"can't tell\" is a valid answer", %{video: v, user: u} do
    answers =
      for l <- ~w(speaker_0 speaker_1 speaker_4), into: %{}, do: {l, %{"who" => "unknown"}}

    assert {:ok, _} = Speakers.confirm(v.id, %{"speakers" => answers, "facts" => @facts}, u)
    assert p(v, "speaker_0").unidentified
  end
end
