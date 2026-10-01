defmodule TopoiWeb.Admin.SpeakersLiveTest do
  use TopoiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures
  import Topoi.IngestFixtures

  alias Topoi.{Review, Videos}

  setup %{conn: conn} do
    jw = debater_fixture(%{name: "Jesus and Whatnot", slug: "jesus-and-whatnot"})
    video = video_fixture()
    Videos.ensure_participants(video, ["speaker_0", "speaker_1"])

    {:ok, _} =
      Review.create_suggestion(%{
        video_id: video.id,
        source: "code",
        kind: "identity",
        raw_label: "speaker_1",
        value: "guest",
        debater_id: jw.id,
        evidence_quote: "Possibly Jesus and Whatnot: chosen as an expected debater at submit."
      })

    %{conn: log_in_user(conn, user_fixture() |> make_admin()), video: video, jw: jw}
  end

  test "shows instructions, samples, and pre-filled answers with their reasons", %{
    conn: conn,
    video: v,
    jw: jw
  } do
    {:ok, lv, html} = live(conn, ~p"/admin/debates/#{v.id}/speakers")

    assert has_element?(lv, "#instructions", "Check who each speaker is")

    assert has_element?(
             lv,
             ~s(select[name="speakers[speaker_1][who]"] option[selected][value="debater:#{jw.id}"])
           )

    assert html =~ "Who: suggested by rule: Possibly Jesus and Whatnot"

    assert has_element?(
             lv,
             ~s(select[name="speakers[speaker_0][who]"] option[value="same:speaker_1"]),
             "Same person as speaker_1"
           )
  end

  test "choosing someone else asks for their name; same-as hides role and side", %{
    conn: conn,
    video: v
  } do
    {:ok, lv, _} = live(conn, ~p"/admin/debates/#{v.id}/speakers")

    lv |> form("#speakers-form", speakers: %{speaker_0: %{who: "name"}}) |> render_change()
    assert has_element?(lv, ~s(input[name="speakers[speaker_0][name]"]))

    lv
    |> form("#speakers-form", speakers: %{speaker_0: %{who: "same:speaker_1"}})
    |> render_change()

    refute has_element?(lv, ~s(select[name="speakers[speaker_0][role]"]))
    assert render(lv) =~ "Takes the identity, role, and side of speaker_1."
  end

  test "errors say what to fix; a valid form confirms the speakers", %{conn: conn, video: v} do
    {:ok, lv, _} = live(conn, ~p"/admin/debates/#{v.id}/speakers")

    html = lv |> form("#speakers-form") |> render_submit()
    assert html =~ "Choose who this is."
    assert html =~ "Choose the debate&#39;s format." or html =~ "Choose the debate's format."

    lv |> form("#speakers-form", speakers: %{speaker_0: %{who: "name"}}) |> render_change()

    html =
      lv
      |> form("#speakers-form",
        speakers: %{
          speaker_0: %{who: "name", name: "The host", role: "host", position: "atheist"},
          speaker_1: %{role: "guest", position: "theist"}
        },
        facts: %{format: "youtube_live", channel_of_record: "debater"}
      )
      |> render_submit()

    assert html =~ "Speakers confirmed. Nothing more to do here."
    assert Videos.get_video!(v.id).status == "speakers_confirmed"
  end
end
