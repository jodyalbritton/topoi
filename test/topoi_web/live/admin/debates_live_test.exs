defmodule TopoiWeb.Admin.DebatesLiveTest do
  use TopoiWeb.ConnCase, async: true
  use Oban.Testing, repo: Topoi.Repo

  import Phoenix.LiveViewTest
  import Topoi.AccountsFixtures
  import Topoi.IngestFixtures

  alias Topoi.{Debaters, Transcripts}
  alias Topoi.Workers

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture() |> make_admin())}
  end

  test "adds a debater with handles and terms", %{conn: conn} do
    {:ok, lv, _} = live(conn, ~p"/admin/debaters")

    html =
      lv
      |> form("#debater-form",
        debater: %{
          name: "Jesus and Whatnot",
          handles: "JesusandWhatnot, Jesus",
          keyterms: "Thomist, actus purus"
        }
      )
      |> render_submit()

    assert html =~ "Added Jesus and Whatnot."
    assert [d] = Debaters.list_debaters()
    assert d.slug == "jesus-and-whatnot"
    assert d.handles == ["JesusandWhatnot", "Jesus"]
    assert d.keyterms == ["Thomist", "actus purus"]
  end

  test "submits a link once; a second submit opens the existing debate", %{conn: conn} do
    d = debater_fixture(%{name: "Jesus and Whatnot", slug: "jesus-and-whatnot"})
    {:ok, lv, _} = live(conn, ~p"/admin/debates")

    html =
      lv
      |> form("#link-form",
        link: %{url: "https://youtu.be/BUm39a7diTU", debater_ids: [d.id], keyterms: "actus purus"}
      )
      |> render_submit()

    assert html =~ "Queued https://www.youtube.com/watch?v=BUm39a7diTU"
    assert html =~ "Queued"
    assert [job] = all_enqueued(worker: Workers.Ingest)

    {:ok, video_id} = Map.fetch(job.args, "video_id")

    assert {:error, {:live_redirect, %{to: to}}} =
             lv
             |> form("#link-form", link: %{url: "https://www.youtube.com/watch?v=BUm39a7diTU"})
             |> render_submit()

    assert to == "/admin/debates/#{video_id}"
    assert length(all_enqueued(worker: Workers.Ingest)) == 1
  end

  test "shows a submit error in plain words", %{conn: conn} do
    {:ok, lv, _} = live(conn, ~p"/admin/debates")
    html = lv |> form("#link-form", link: %{url: "https://vimeo.com/1"}) |> render_submit()
    assert html =~ "Only YouTube and TikTok video links are supported."
  end

  test "a pasted transcript opens its debate page with turns once normalized", %{conn: conn} do
    {:ok, lv, _} = live(conn, ~p"/admin/debates")
    lv |> element("button", "Paste transcript") |> render_click()

    paste = """
    00:00:00,000 --> 00:00:05,000 [Speaker 0]
    Welcome to the show, today we talk about the five ways.

    00:00:05,500 --> 00:00:09,000 [Speaker 1]
    Thanks for having me on, glad to be here.\
    """

    assert {:error, {:live_redirect, %{to: "/admin/debates/" <> id}}} =
             lv |> form("#paste-form", paste: %{text: paste}) |> render_submit()

    t = Transcripts.live_transcript(id)
    assert :ok = perform_job(Workers.Normalize, %{transcript_id: t.id})

    {:ok, _lv, html} = live(conn, ~p"/admin/debates/#{id}")
    assert html =~ "Turns ready"
    assert html =~ "Welcome to the show"
    assert html =~ "speaker_1"
  end

  test "the list updates when a worker changes a video", %{conn: conn} do
    video = video_fixture()
    {:ok, lv, html} = live(conn, ~p"/admin/debates")
    assert html =~ "Queued"

    {:ok, _} = Topoi.Videos.set_status(video, "failed", "Something broke upstream")
    assert render(lv) =~ "Something broke upstream"
  end
end
