defmodule Topoi.Participants.CandidatesTest do
  use Topoi.DataCase, async: true

  import Topoi.IngestFixtures

  alias Topoi.{Review, Videos}
  alias Topoi.Participants.Candidates

  setup do
    jw =
      debater_fixture(%{
        name: "Jesus and Whatnot",
        slug: "jesus-and-whatnot",
        handles: ["JesusandWhatnot"]
      })

    rz = debater_fixture(%{name: "Redeemed Zoomer", slug: "redeemed-zoomer"})
    %{jw: jw, rz: rz}
  end

  defp video_with(channel, debater_ids) do
    v = video_fixture(%{}, debater_ids)
    {:ok, v} = Videos.put_metadata(v, %{channel_name: channel})
    Videos.ensure_participants(v, ["speaker_0", "speaker_1"])
    v
  end

  defp all(v), do: Review.suggestions_by_label(v.id) |> Map.values() |> List.flatten()

  test "suggests unlinked expected and channel debaters for each unlinked label", %{jw: jw} do
    v = video_with("Jesus and Whatnot", [jw.id])

    {:ok, _} =
      Review.create_suggestion(%{
        video_id: v.id,
        kind: "identity",
        raw_label: "speaker_1",
        value: "host",
        source: "model"
      })

    assert Candidates.suggest(v) == 3

    links = all(v) |> Enum.filter(&(&1.source == "code" and &1.kind == "identity"))
    assert links |> Enum.map(& &1.raw_label) |> Enum.sort() == ["speaker_0", "speaker_1"]
    assert Enum.all?(links, &(&1.debater_id == jw.id))

    link1 = Enum.find(links, &(&1.raw_label == "speaker_1"))
    assert link1.value == "host"
    assert link1.evidence_quote =~ "expected debater at submit"
    assert link1.evidence_quote =~ "on this debater's channel (Jesus and Whatnot)"

    assert [%{value: "debater", debater_id: id}] =
             Enum.filter(all(v), &(&1.kind == "channel_of_record"))

    assert id == jw.id
  end

  test "does not re-suggest a debater the model already linked, nor link labels already linked",
       %{jw: jw, rz: rz} do
    v = video_with("Some Third Channel", [jw.id, rz.id])

    {:ok, _} =
      Review.create_suggestion(%{
        video_id: v.id,
        kind: "identity",
        raw_label: "speaker_1",
        value: "guest",
        debater_id: jw.id,
        source: "model"
      })

    assert Candidates.suggest(v) == 1

    assert [%{raw_label: "speaker_0", debater_id: id}] =
             all(v) |> Enum.filter(&(&1.source == "code"))

    assert id == rz.id
  end
end
