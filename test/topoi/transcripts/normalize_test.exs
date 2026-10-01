defmodule Topoi.Transcripts.NormalizeTest do
  use Topoi.DataCase, async: true

  import Topoi.IngestFixtures

  alias Topoi.Samples
  alias Topoi.Settings.Pipeline
  alias Topoi.Transcripts
  alias Topoi.Transcripts.{Normalize, Parsers}

  @settings %Pipeline{}

  # Builds indexed words from {label, start_s, end_s, text} segments.
  defp words(segments) do
    segments
    |> Enum.map(fn {label, s, e, text} ->
      %{start_ms: round(s * 1000), end_ms: round(e * 1000), raw_label: label, text: text}
    end)
    |> Parsers.srt_words()
    |> Enum.with_index()
    |> Enum.map(fn {w, i} -> Map.put(w, :idx, i) end)
  end

  defp build(segments), do: Normalize.build(words(segments), @settings)

  test "merges one speaker's segments across short gaps, splits on long ones" do
    {turns, _} =
      build([
        {"speaker_0", 0, 3, "one two three four five six seven"},
        {"speaker_0", 5, 8, "eight nine ten eleven twelve thirteen"},
        {"speaker_0", 20, 23, "fourteen fifteen sixteen seventeen eighteen nineteen"}
      ])

    assert [%{start_ms: 0, end_ms: 8000, word_count: 13}, %{start_ms: 20_000}] = turns
  end

  test "marks short answers as backchannel but keeps questions substantive" do
    {turns, stats} =
      build([
        {"speaker_0", 0, 10, "a long point with many words in it to make"},
        {"speaker_1", 10.2, 11, "yeah right"},
        {"speaker_1", 30, 31, "really?"}
      ])

    assert Enum.map(turns, & &1.kind) == ["substantive", "backchannel", "substantive"]
    assert stats.backchannel == 1
  end

  test "bridges a speaker's turn across the other side's backchannel" do
    {turns, stats} =
      build([
        {"speaker_0", 0, 10, "the first part of a long argument about motion"},
        {"speaker_1", 10.5, 11, "mm-hmm"},
        {"speaker_0", 12, 20, "and the second part continues the same line"}
      ])

    assert [
             %{raw_label: "speaker_0", start_ms: 0, end_ms: 20_000, word_count: 17},
             %{kind: "backchannel"}
           ] =
             turns

    assert stats.turns_before_bridge == 3
    assert stats.substantive == 1
  end

  test "does not bridge beyond the window" do
    {turns, _} =
      build([
        {"speaker_0", 0, 10, "the first part of a long argument about motion"},
        {"speaker_1", 10.5, 11, "mm-hmm"},
        {"speaker_0", 30, 40, "a separate point much later in the debate here"}
      ])

    assert Enum.count(turns, &(&1.kind == "substantive")) == 2
  end

  test "marks cut-off and resumed turns as interrupted" do
    {turns, _} =
      build([
        {"speaker_0", 0, 5, "so the argument from motion says that um-"},
        {"speaker_1", 5, 9, "wait wait you have to prove it is God"},
        {"speaker_0", 9.1, 12, "...as I was saying nothing moves itself"}
      ])

    assert Enum.map(turns, & &1.interrupted) == [true, false, true]
  end

  test "thresholds come from settings" do
    segments = [
      {"speaker_0", 0, 3, "one two three four five six seven"},
      {"speaker_0", 5, 8, "eight nine ten eleven twelve thirteen"}
    ]

    # Bridging also rejoins adjacent same-speaker turns, so both
    # thresholds must drop to split them.
    {turns, _} = Normalize.build(words(segments), %{@settings | merge_gap_ms: 1_000})
    assert length(turns) == 1

    {turns, _} =
      Normalize.build(words(segments), %{@settings | merge_gap_ms: 1_000, bridge_window_ms: 1_000})

    assert length(turns) == 2
  end

  test "run/1 stores turns and participants and marks the video normalized" do
    video = video_fixture()
    transcript = transcript_fixture(video)

    {:ok, _} =
      Transcripts.put_words(
        transcript,
        words([
          {"speaker_0", 0, 10, "the first part of a long argument about motion"},
          {"speaker_1", 10.5, 15, "you still have to prove that it is God"}
        ])
      )

    assert {:ok, %{substantive: 2}} = Normalize.run(transcript)
    assert Transcripts.turn_counts(transcript.id) == %{"substantive" => 2}
    assert Topoi.Videos.get_video!(video.id).status == "normalized"
    assert length(Topoi.Videos.ensure_participants(video, [])) == 2
  end

  describe "gold samples (PRD §9.1 measurements)" do
    @describetag :samples

    # Measured 2026-10-01 with default settings. The xh9D0oLxwQg probe
    # reported 941 segments / 893 / 256 / 518: it dropped one block, and
    # it counted an audio-only "[laughs]" segment as a turn.
    for {id, segments, before_bridge, backchannel, substantive} <- [
          {"xh9D0oLxwQg", 942, 891, 254, 518},
          {"RwoZn83IHgo", 590, 553, 222, 189},
          {"UaC-gqcT7JI", 155, 131, 43, 63},
          {"cPVtaKPLC9Q", 804, 744, 210, 436}
        ] do
      @tag skip: !Samples.present?(Samples.srt(id)) && "sample #{id} not present"
      test "#{id}" do
        {:ok, segs} = Parsers.srt_segments(File.read!(Samples.srt(unquote(id))))
        assert length(segs) == unquote(segments)

        indexed =
          segs
          |> Parsers.srt_words()
          |> Enum.with_index()
          |> Enum.map(fn {w, i} -> Map.put(w, :idx, i) end)

        {_turns, stats} = Normalize.build(indexed, @settings)

        assert stats == %{
                 turns_before_bridge: unquote(before_bridge),
                 backchannel: unquote(backchannel),
                 substantive: unquote(substantive)
               }
      end
    end
  end
end
