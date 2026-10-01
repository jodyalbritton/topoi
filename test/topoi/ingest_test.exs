defmodule Topoi.IngestTest do
  use Topoi.DataCase, async: true
  use Oban.Testing, repo: Topoi.Repo

  import Topoi.IngestFixtures

  alias Topoi.{Ingest, Settings, Transcripts, Videos}
  alias Topoi.Ingest.Keyterms
  alias Topoi.Transcripts.ElevenLabs
  alias Topoi.Workers

  @url "https://youtu.be/BUm39a7diTU?si=x"

  defp elevenlabs_payload do
    %{
      "language_code" => "eng",
      "audio_duration_secs" => 20.0,
      "transcription_id" => "tx_1",
      "words" => [
        %{
          "text" => "Hey,",
          "type" => "word",
          "start" => 0.0,
          "end" => 0.4,
          "speaker_id" => "speaker_0"
        },
        %{
          "text" => " ",
          "type" => "spacing",
          "start" => 0.4,
          "end" => 0.5,
          "speaker_id" => "speaker_0"
        },
        %{
          "text" => "welcome",
          "type" => "word",
          "start" => 0.5,
          "end" => 0.9,
          "speaker_id" => "speaker_0"
        },
        %{
          "text" => "to",
          "type" => "word",
          "start" => 0.9,
          "end" => 1.0,
          "speaker_id" => "speaker_0"
        },
        %{
          "text" => "the",
          "type" => "word",
          "start" => 1.0,
          "end" => 1.1,
          "speaker_id" => "speaker_0"
        },
        %{
          "text" => "show",
          "type" => "word",
          "start" => 1.1,
          "end" => 1.5,
          "speaker_id" => "speaker_0"
        },
        %{
          "text" => "today",
          "type" => "word",
          "start" => 1.5,
          "end" => 2.5,
          "speaker_id" => "speaker_0"
        },
        %{
          "text" => "Thanks",
          "type" => "word",
          "start" => 3.0,
          "end" => 3.4,
          "speaker_id" => "speaker_1"
        },
        %{
          "text" => "for",
          "type" => "word",
          "start" => 3.4,
          "end" => 3.6,
          "speaker_id" => "speaker_1"
        },
        %{
          "text" => "having",
          "type" => "word",
          "start" => 3.6,
          "end" => 3.9,
          "speaker_id" => "speaker_1"
        },
        %{
          "text" => "me",
          "type" => "word",
          "start" => 3.9,
          "end" => 4.1,
          "speaker_id" => "speaker_1"
        },
        %{
          "text" => "on",
          "type" => "word",
          "start" => 4.1,
          "end" => 4.3,
          "speaker_id" => "speaker_1"
        },
        %{
          "text" => "here",
          "type" => "word",
          "start" => 4.3,
          "end" => 6.0,
          "speaker_id" => "speaker_1"
        }
      ]
    }
  end

  defp stub_metadata do
    Req.Test.stub(Topoi.Metadata, fn conn ->
      Req.Test.json(conn, %{
        "title" => "Redeemed Zoomer + JesusandWhatnot |Catholicism|",
        "author_name" => "Jesus and Whatnot"
      })
    end)
  end

  defp stub_elevenlabs(test_pid, response_fun) do
    Req.Test.stub(ElevenLabs, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)
      send(test_pid, {:elevenlabs_called, conn, body})
      response_fun.(conn)
    end)
  end

  setup do
    {:ok, _} = Settings.update(Topoi.Settings.ElevenLabs, %{api_key: "sk_test"})
    :ok
  end

  describe "submit_url/3" do
    test "creates the video once and queues one ingest job" do
      d = debater_fixture(%{name: "Jesus and Whatnot", slug: "jesus-and-whatnot"})
      assert {:ok, video} = Ingest.submit_url(@url, [d.id], ["actus purus"])
      assert video.canonical_url == "https://www.youtube.com/watch?v=BUm39a7diTU"
      assert_enqueued(worker: Workers.Ingest, args: %{video_id: video.id})

      assert {:existing, same} =
               Ingest.submit_url("https://www.youtube.com/watch?v=BUm39a7diTU&t=5")

      assert same.id == video.id
      assert length(all_enqueued(worker: Workers.Ingest)) == 1
    end

    test "rejects unsupported links" do
      assert {:error, "Only YouTube and TikTok" <> _} = Ingest.submit_url("https://vimeo.com/1")
    end
  end

  describe "ingest worker" do
    test "fetches details, transcribes once with keyterms, stores words, queues normalize" do
      stub_metadata()
      stub_elevenlabs(self(), &Req.Test.json(&1, elevenlabs_payload()))

      d =
        debater_fixture(%{
          name: "Jesus and Whatnot",
          slug: "jesus-and-whatnot",
          handles: ["JesusandWhatnot"]
        })

      {:ok, video} = Ingest.submit_url(@url, [d.id], ["actus purus"])

      assert :ok = perform_job(Workers.Ingest, %{video_id: video.id})

      assert_received {:elevenlabs_called, conn, body}
      assert Plug.Conn.get_req_header(conn, "xi-api-key") == ["sk_test"]
      assert body =~ "https://www.youtube.com/watch?v=BUm39a7diTU"
      assert body =~ ~s(name="keyterms"\r\n\r\nactus purus)
      assert body =~ ~s(name="keyterms"\r\n\r\nRedeemed Zoomer)
      assert body =~ ~s(name="no_verbatim"\r\n\r\nfalse)

      transcript = Transcripts.live_transcript(video.id)
      assert transcript.status == "received"
      assert transcript.request_params["keyterms"] |> Enum.member?("Jesus and Whatnot")
      refute Map.has_key?(transcript.request_params, "xi-api-key")
      assert Transcripts.count_words(transcript.id) == 12

      video = Videos.get_video!(video.id)
      assert video.status == "transcribed"
      assert video.title =~ "Redeemed Zoomer"
      assert video.duration_ms == 20_000
      assert_enqueued(worker: Workers.Normalize, args: %{transcript_id: transcript.id})

      assert :ok = perform_job(Workers.Normalize, %{transcript_id: transcript.id})
      assert %{"substantive" => 2} = Transcripts.turn_counts(transcript.id)
      assert Videos.get_video!(video.id).status == "normalized"

      # A second run for the same video makes no call.
      assert :ok = perform_job(Workers.Ingest, %{video_id: video.id})
      refute_received {:elevenlabs_called, _, _}
    end

    test "retries a failed upstream download, then succeeds" do
      stub_metadata()

      stub_elevenlabs(self(), fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{
          "detail" => %{
            "message" =>
              "Failed to download the file from the provided URL (upstream status 400)."
          }
        })
      end)

      {:ok, video} = Ingest.submit_url(@url)

      assert {:error, "Failed to download" <> _} =
               perform_job(Workers.Ingest, %{video_id: video.id})

      assert Videos.get_video!(video.id).last_error =~ "Retrying"

      stub_elevenlabs(self(), &Req.Test.json(&1, elevenlabs_payload()))
      assert :ok = perform_job(Workers.Ingest, %{video_id: video.id}, attempt: 2)
      assert Transcripts.live_transcript(video.id).status == "received"
    end

    test "gives up on the last attempt and on permanent errors" do
      stub_metadata()

      stub_elevenlabs(self(), fn conn ->
        conn |> Plug.Conn.put_status(422) |> Req.Test.json(%{"detail" => "invalid model_id"})
      end)

      {:ok, video} = Ingest.submit_url(@url)
      assert {:cancel, "invalid model_id"} = perform_job(Workers.Ingest, %{video_id: video.id})

      video = Videos.get_video!(video.id)
      assert video.status == "failed"
      assert video.last_error == "invalid model_id"
      assert Transcripts.live_transcript(video.id) == nil
    end

    test "without a key, the job stops with a direction" do
      Repo.delete_all(Topoi.Settings.ElevenLabs)
      stub_metadata()
      {:ok, video} = Ingest.submit_url(@url)

      assert {:cancel, :not_configured} = perform_job(Workers.Ingest, %{video_id: video.id})
      assert Videos.get_video!(video.id).last_error =~ "/admin/settings"
    end
  end

  describe "submit_paste/3" do
    @paste """
    00:00:00,000 --> 00:00:05,000 [Speaker 0]
    Welcome to the show, today we talk about the five ways.

    00:00:05,500 --> 00:00:09,000 [Speaker 1]
    Thanks for having me on, glad to be here.\
    """

    test "stores words and queues normalization" do
      assert {:ok, video} = Ingest.submit_paste(@paste)
      assert video.platform == "none"
      t = Transcripts.live_transcript(video.id)
      assert t.provider == "paste"
      assert Transcripts.count_words(t.id) == 20
      assert_enqueued(worker: Workers.Normalize, args: %{transcript_id: t.id})
    end

    test "refuses a paste for a video that already has a transcript" do
      video =
        video_fixture(%{
          platform_video_id: "BUm39a7diTU",
          canonical_url: "https://www.youtube.com/watch?v=BUm39a7diTU"
        })

      transcript_fixture(video)
      assert {:error, "That video already has a transcript."} = Ingest.submit_paste(@paste, @url)
    end

    test "reports a malformed paste" do
      assert {:error, "No timed [Speaker N] blocks" <> _} = Ingest.submit_paste("hello")
    end
  end

  describe "import_elevenlabs/3" do
    test "stores a response without a call and queues normalization" do
      Req.Test.stub(ElevenLabs, fn _ -> flunk("no call expected") end)
      stub_metadata()

      assert {:ok, video} = Ingest.import_elevenlabs(@url, elevenlabs_payload())
      t = Transcripts.live_transcript(video.id)
      assert t.provider == "elevenlabs"
      assert t.request_params == %{"imported" => true}
      assert Videos.get_video!(video.id).title =~ "Redeemed Zoomer"
      assert Transcripts.count_words(t.id) == 12
      assert_enqueued(worker: Workers.Normalize, args: %{transcript_id: t.id})

      assert {:error, "That video already has a transcript."} =
               Ingest.import_elevenlabs(@url, elevenlabs_payload())
    end
  end

  describe "keyterms" do
    test "names, handles, terms, title fragments, extras; deduped and limited" do
      d = %{
        name: "Jesus and Whatnot",
        handles: ["JesusandWhatnot"],
        keyterms: ["Thomist", "actus purus"]
      }

      video = %{
        channel_name: "Jesus and Whatnot",
        title: "Redeemed Zoomer + JesusandWhatnot |Catholicism|"
      }

      {terms, dropped} =
        Keyterms.build([d], video, [
          "a term that is far too long to be accepted by the API at all",
          "one two three four five six"
        ])

      assert terms == [
               "Jesus and Whatnot",
               "JesusandWhatnot",
               "Thomist",
               "actus purus",
               "Redeemed Zoomer"
             ]

      assert length(dropped) == 2
    end
  end
end
