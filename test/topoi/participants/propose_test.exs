defmodule Topoi.Participants.ProposeTest do
  use Topoi.DataCase, async: true
  use Oban.Testing, repo: Topoi.Repo

  import Topoi.IngestFixtures

  alias Topoi.AI.Gateway
  alias Topoi.{Ingest, Review, Samples, Settings, Transcripts, Videos}
  alias Topoi.Participants.{MergeHints, Propose}
  alias Topoi.Transcripts.{Normalize, Parsers}
  alias Topoi.Workers

  @paste """
  00:00:00,000 --> 00:00:06,000 [Speaker 0]
  Everybody welcome in, today on my channel I have Jesus and Whatnot here with me.

  00:00:06,500 --> 00:00:14,000 [Speaker 1]
  Thanks for having me. I'm a Thomist and I'm here to show you that God exists.

  00:00:14,500 --> 00:00:20,000 [Speaker 0]
  Well, I'm a proud atheist, so you are going to have to prove it to me.\
  """

  defp answer(map) do
    Req.Test.stub(Gateway, fn conn ->
      Req.Test.json(conn, %{
        "model" => "qwen",
        "choices" => [%{"message" => %{"content" => Jason.encode!(map)}}]
      })
    end)
  end

  defp speaker(label, overrides) do
    Map.merge(
      %{
        "raw_label" => label,
        "role" => "host",
        "stated_name" => "",
        "name_quote" => "",
        "role_quote" => "",
        "position" => "undeclared",
        "position_quote" => "",
        "merge_with" => "",
        "confidence" => 0.9
      },
      overrides
    )
  end

  setup do
    {:ok, _} = Settings.update(Topoi.Settings.Gateway, %{api_key: "k"})

    d =
      debater_fixture(%{
        name: "Jesus and Whatnot",
        slug: "jesus-and-whatnot",
        handles: ["JesusandWhatnot"]
      })

    {:ok, video} = Ingest.submit_paste(@paste)
    t = Transcripts.live_transcript(video.id)
    {:ok, _} = Normalize.run(t)
    %{video: video, transcript: t, debater: d}
  end

  test "creates evidenced suggestions; drops invented quotes; matches names by code", %{
    video: video,
    transcript: t,
    debater: d
  } do
    answer(%{
      "format" => "youtube_live",
      "format_quote" => "today on my channel",
      "speakers" => [
        speaker("speaker_0", %{
          "role_quote" => "today on my channel I have",
          "position" => "atheist",
          "position_quote" => "I'm a proud atheist"
        }),
        speaker("speaker_1", %{
          "role" => "guest",
          "stated_name" => "Jesus and Whatnot",
          "name_quote" => "I have Jesus and Whatnot here with me",
          "position" => "theist",
          "position_quote" => "I am certainly a believer in all of this"
        })
      ]
    })

    assert {:ok, %{created: 4, dropped: ["speaker_1 position: quote not found"]}} = Propose.run(t)

    by_label = Review.suggestions_by_label(video.id)
    [host_id, host_pos] = Enum.sort_by(by_label["speaker_0"], & &1.kind)
    assert {host_id.kind, host_id.value, host_id.evidence_ms} == {"identity", "host", 0}
    assert {host_pos.value, host_pos.evidence_quote} == {"atheist", "I'm a proud atheist"}

    [guest] = by_label["speaker_1"]
    assert guest.stated_name == "Jesus and Whatnot"
    assert guest.debater_id == d.id
    assert guest.llm_call_id

    assert [%{kind: "format", value: "youtube_live"}] = by_label[nil]
    assert Videos.get_video!(video.id).status == "speakers_suggested"
  end

  test "a quote that only mentions a handle does not link a speaker who claims no name", %{
    video: video,
    transcript: t
  } do
    answer(%{
      "format" => "podcast",
      "format_quote" => "today on my channel",
      "speakers" => [
        speaker("speaker_0", %{
          "name_quote" => "I have Jesus and Whatnot here with me",
          "role_quote" => "today on my channel I have"
        })
      ]
    })

    {:ok, _} = Propose.run(t)

    [identity] =
      Review.suggestions_by_label(video.id)["speaker_0"]
      |> Enum.filter(&(&1.kind == "identity" and &1.source == "model"))

    assert identity.debater_id == nil
  end

  test "the model is not shown debater records", %{transcript: t} do
    Req.Test.stub(Gateway, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      refute body =~ "jesus-and-whatnot"
      refute body =~ "JesusandWhatnot\\\""

      Req.Test.json(conn, %{
        "choices" => [
          %{"message" => %{"content" => ~s({"format":"podcast","format_quote":"","speakers":[]})}}
        ]
      })
    end)

    assert {:ok, _} = Propose.run(t)
  end

  test "a re-run replaces undecided suggestions only", %{video: video, transcript: t} do
    answer(%{"format" => "podcast", "format_quote" => "today on my channel", "speakers" => []})
    {:ok, _} = Propose.run(t)
    {:ok, _} = Propose.run(t)
    assert [%{kind: "format"}] = Review.suggestions_by_label(video.id)[nil]
  end

  test "normalize queues the proposal only when the gateway is configured", %{transcript: t} do
    assert :ok = perform_job(Workers.Normalize, %{transcript_id: t.id})
    assert_enqueued(worker: Workers.Participants, args: %{transcript_id: t.id})

    Repo.delete_all(Topoi.Settings.Gateway)
    Repo.delete_all(Oban.Job)
    assert :ok = perform_job(Workers.Normalize, %{transcript_id: t.id})
    refute_enqueued(worker: Workers.Participants)
  end

  test "locate/3 ignores case, punctuation, and spacing" do
    turns = [%{text: "Uh, I'm a  Thomist, and...", start_ms: 4200}]
    assert {:ok, _, 4200} = Propose.locate("i'm a thomist and", turns, "")
    assert :not_found = Propose.locate("I'm an atheist", turns, "")
    assert {:ok, _, nil} = Propose.locate("my channel", [], "my channel")
  end

  test "stitched quotes count only when every excerpt is found" do
    turns = [
      %{text: "Uh, so you're an atheist.", start_ms: 21_000},
      %{text: "I'm approaching this from a logical proof", start_ms: 40_000}
    ]

    assert {:ok, _, 21_000} =
             Propose.locate("so you're an atheist ... a logical proof", turns, "")

    assert :not_found = Propose.locate("so you're an atheist … something never said", turns, "")
  end

  test "names and handles inside the quote link a debater" do
    d = %{
      id: "d1",
      name: "Jesus and Whatnot",
      handles: ["JesusandWhatnot"],
      slug: "jesus-and-whatnot"
    }

    assert Propose.mentioned_debater("Noah Beeser, AKA Jesusandwhatnot. Thank you", [d]) == "d1"
    assert Propose.mentioned_debater("Channel: Jesus and Whatnot", [d]) == "d1"
    assert Propose.mentioned_debater("nothing here", [d]) == nil
  end

  describe "merge hints" do
    test "flag a label that picks up another's cut-off sentence while the first is silent" do
      turns = [
        %{
          raw_label: "speaker_1",
          start_ms: 0,
          end_ms: 9_000,
          text: "My argument is from motion and nothing moves itself."
        },
        %{
          raw_label: "speaker_2",
          start_ms: 9_500,
          end_ms: 15_000,
          text: "But you have to prove it is God."
        },
        %{
          raw_label: "speaker_1",
          start_ms: 15_200,
          end_ms: 30_000,
          text: "Even though Nate never presented"
        },
        %{
          raw_label: "speaker_4",
          start_ms: 30_700,
          end_ms: 60_000,
          text: "uh to prove that the Bible was contradictory."
        },
        %{raw_label: "speaker_1", start_ms: 90_000, end_ms: 95_000, text: "Back to my point."}
      ]

      assert [{"speaker_4", "speaker_1", evidence, 30_700}] = MergeHints.handoffs(turns)
      assert evidence =~ "stops mid-sentence"
    end

    @tag :samples
    @tag skip: !Samples.present?(Samples.srt("cPVtaKPLC9Q")) && "sample not present"
    test "cPVtaKPLC9Q: the fifth label is flagged as the Thomist's (PRD §14)" do
      {:ok, segs} = Parsers.srt_segments(File.read!(Samples.srt("cPVtaKPLC9Q")))

      words =
        segs
        |> Parsers.srt_words()
        |> Enum.with_index()
        |> Enum.map(fn {w, i} -> Map.put(w, :idx, i) end)

      {turns, _} = Normalize.build(words, %Topoi.Settings.Pipeline{})
      by_idx = Map.new(words, &{&1.idx, &1})

      turns =
        Enum.map(turns, fn t ->
          text =
            t.first_word_idx..t.last_word_idx
            |> Enum.map(&by_idx[&1])
            |> Enum.filter(&(&1.raw_label == t.raw_label and &1.kind == "word"))
            |> Enum.map_join(" ", & &1.text)

          Map.put(t, :text, text)
        end)

      assert [{"speaker_4", "speaker_1", _, 4_754_160}] = MergeHints.handoffs(turns)
    end
  end
end
