defmodule Topoi.IngestSchemaTest do
  use Topoi.DataCase, async: true

  import Topoi.IngestFixtures

  alias Topoi.{Debaters, Transcripts, Videos}

  describe "debaters" do
    test "slugs are lowercase, hyphenated, unique, and not reserved" do
      assert {:ok, d} = Debaters.create_debater(%{slug: "Jesus-And-Whatnot", name: "J"})
      assert d.slug == "jesus-and-whatnot"

      assert {:error, cs} = Debaters.create_debater(%{slug: "jesus-and-whatnot", name: "J2"})
      assert "has already been taken" in errors_on(cs).slug

      assert {:error, cs} = Debaters.create_debater(%{slug: "admin", name: "A"})
      assert "is reserved" in errors_on(cs).slug

      assert {:error, cs} = Debaters.create_debater(%{slug: "has space", name: "A"})
      assert errors_on(cs).slug != []
    end
  end

  describe "videos" do
    test "one row per (platform, platform_video_id)" do
      video_fixture(%{platform_video_id: "BUm39a7diTU"})

      assert {:error, cs} =
               Videos.create_video(%{
                 platform: "youtube",
                 platform_video_id: "BUm39a7diTU",
                 canonical_url: "https://www.youtube.com/watch?v=BUm39a7diTU"
               })

      assert "has already been submitted" in errors_on(cs).platform
    end

    test "pastes without a URL are exempt from the unique index" do
      assert {:ok, _} = Videos.create_video(%{platform: "none"})
      assert {:ok, _} = Videos.create_video(%{platform: "none"})
    end

    test "expected debaters attach at creation" do
      d = debater_fixture()
      video = video_fixture(%{}, [d.id])
      assert [%{id: id}] = Videos.get_video!(video.id).debaters
      assert id == d.id
    end

    test "participants are created once per raw label" do
      video = video_fixture()
      Videos.ensure_participants(video, ["speaker_0", "speaker_1", "speaker_0"])
      assert length(Videos.ensure_participants(video, ["speaker_1"])) == 2
    end
  end

  describe "transcripts" do
    test "at most one live transcript per video" do
      video = video_fixture()
      transcript_fixture(video)

      assert {:error, cs} =
               Transcripts.create_transcript(%{
                 video_id: video.id,
                 provider: "elevenlabs",
                 status: "pending"
               })

      assert "already has a live transcript" in errors_on(cs).video_id
    end

    test "a failed transcript does not block a new one" do
      video = video_fixture()
      transcript_fixture(video, %{status: "failed"})

      assert {:ok, _} =
               Transcripts.create_transcript(%{video_id: video.id, provider: "elevenlabs"})
    end

    test "words and turns are stored in order and replaced wholesale" do
      t = transcript_fixture(video_fixture())

      words =
        for i <- 0..4999,
            do: %{text: "w#{i}", start_ms: i * 100, end_ms: i * 100 + 90, raw_label: "speaker_0"}

      assert {:ok, 5000} = Transcripts.put_words(t, words)
      assert {:ok, 1} = Transcripts.put_words(t, [hd(words)])
      assert Transcripts.count_words(t.id) == 1

      turn = %{
        raw_label: "speaker_0",
        first_word_idx: 0,
        last_word_idx: 0,
        start_ms: 0,
        end_ms: 90,
        word_count: 1,
        kind: "backchannel",
        interrupted: false
      }

      assert {:ok, 2} = Transcripts.put_turns(t, [turn, %{turn | kind: "substantive"}])
      assert Transcripts.turn_counts(t.id) == %{"backchannel" => 1, "substantive" => 1}
      assert [%{idx: 0}, %{idx: 1}] = Transcripts.list_turns(t.id)
    end
  end
end
