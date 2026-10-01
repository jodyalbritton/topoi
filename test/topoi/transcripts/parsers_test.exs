defmodule Topoi.Transcripts.ParsersTest do
  use ExUnit.Case, async: true

  alias Topoi.Samples
  alias Topoi.Transcripts.Parsers

  describe "srt_segments/1" do
    test "keeps the final block without a trailing blank line" do
      text = """
      00:00:00,300 --> 00:00:02,080 [Speaker 0]
      Everybody, welcome in.

      00:00:03,000 --> 00:00:03,840 [Speaker 1]
      Hey, how you doing?\
      """

      assert {:ok, [first, last]} = Parsers.srt_segments(text)

      assert first == %{
               start_ms: 300,
               end_ms: 2080,
               raw_label: "speaker_0",
               text: "Everybody, welcome in."
             }

      assert last.text == "Hey, how you doing?"
      assert last.raw_label == "speaker_1"
    end

    test "handles CRLF and hour timestamps" do
      text = "01:02:03,004 --> 01:02:05,000 [Speaker 2]\r\nLate words.\r\n"
      assert {:ok, [%{start_ms: 3_723_004, raw_label: "speaker_2"}]} = Parsers.srt_segments(text)
    end

    test "rejects text without timed speaker blocks" do
      assert {:error, msg} = Parsers.srt_segments("just some text")
      assert msg =~ "No timed [Speaker N] blocks"
    end

    test "rejects a paste whose tags and blocks disagree" do
      text = "00:00:00,000 --> 00:00:01,000 [Speaker 0]\nI said [Speaker 1] out loud."
      assert {:error, msg} = Parsers.srt_segments(text)
      assert msg =~ "malformed"
    end
  end

  describe "srt_words/1" do
    test "spreads segment time across words and marks audio events" do
      [a, b, c] =
        Parsers.srt_words([
          %{start_ms: 0, end_ms: 300, raw_label: "speaker_0", text: "yes [laughs] no"}
        ])

      assert {a.start_ms, a.end_ms, a.kind} == {0, 100, "word"}
      assert b.kind == "audio_event"
      assert c.end_ms == 300
    end
  end

  describe "elevenlabs_words/1" do
    test "drops spacing, keeps audio events, converts to ms" do
      payload = %{
        "words" => [
          %{
            "text" => "Hey,",
            "type" => "word",
            "start" => 0.86,
            "end" => 0.96,
            "speaker_id" => "speaker_0",
            "logprob" => -0.06
          },
          %{
            "text" => " ",
            "type" => "spacing",
            "start" => 0.96,
            "end" => 1.04,
            "speaker_id" => "speaker_0"
          },
          %{
            "text" => "[laughs]",
            "type" => "audio_event",
            "start" => 1.5,
            "end" => 2.0,
            "speaker_id" => "speaker_1"
          }
        ]
      }

      assert [
               %{text: "Hey,", kind: "word", start_ms: 860, end_ms: 960, raw_label: "speaker_0"},
               %{text: "[laughs]", kind: "audio_event", start_ms: 1500, raw_label: "speaker_1"}
             ] = Parsers.elevenlabs_words(payload)
    end
  end

  describe "gold samples" do
    @describetag :samples

    for id <- ~w(xh9D0oLxwQg RwoZn83IHgo UaC-gqcT7JI cPVtaKPLC9Q) do
      @tag skip: !Samples.present?(Samples.srt(id)) && "sample #{id} not present"
      test "#{id}: segments equal speaker tags" do
        text = File.read!(Samples.srt(unquote(id)))
        tags = length(Regex.scan(~r/\[Speaker\s+\d+\]/, text))
        assert {:ok, segments} = Parsers.srt_segments(text)
        assert length(segments) == tags
      end
    end

    @tag skip:
           !Samples.present?(Samples.elevenlabs_json("BUm39a7diTU")) && "API sample not present"
    test "BUm39a7diTU API response parses to 18,196 words and 20 audio events" do
      payload = Samples.elevenlabs_json("BUm39a7diTU") |> File.read!() |> Jason.decode!()
      words = Parsers.elevenlabs_words(payload)
      assert Enum.count(words, &(&1.kind == "word")) == 18_196
      assert Enum.count(words, &(&1.kind == "audio_event")) == 20
    end
  end
end
