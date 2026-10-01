defmodule Topoi.Ingest.CanonicalizeTest do
  use ExUnit.Case, async: true

  alias Topoi.Ingest.Canonicalize

  @yt "BUm39a7diTU"
  @canonical "https://www.youtube.com/watch?v=#{@yt}"

  for url <- [
        "https://www.youtube.com/watch?v=BUm39a7diTU",
        "https://youtube.com/watch?v=BUm39a7diTU&t=120s",
        "https://m.youtube.com/watch?v=BUm39a7diTU&si=abc&feature=share",
        "https://music.youtube.com/watch?v=BUm39a7diTU&list=PL1&pp=x",
        "https://www.youtube.com/watch?feature=share&v=BUm39a7diTU",
        "https://youtu.be/BUm39a7diTU",
        "https://youtu.be/BUm39a7diTU?si=tracking&t=30",
        "https://www.youtube.com/shorts/BUm39a7diTU",
        "https://www.youtube.com/live/BUm39a7diTU?feature=shared",
        "https://www.youtube.com/embed/BUm39a7diTU",
        "https://www.youtube-nocookie.com/embed/BUm39a7diTU",
        "www.youtube.com/watch?v=BUm39a7diTU",
        "  https://www.youtube.com/watch?v=BUm39a7diTU  "
      ] do
    test "YouTube: #{url}" do
      assert {:ok, %{platform: "youtube", platform_video_id: @yt, canonical_url: @canonical}} =
               Canonicalize.parse(unquote(url))
    end
  end

  test "TikTok video link" do
    assert {:ok,
            %{
              platform: "tiktok",
              platform_video_id: "7301234567890123456",
              canonical_url: "https://www.tiktok.com/@someone/video/7301234567890123456"
            }} =
             Canonicalize.parse(
               "https://www.tiktok.com/@someone/video/7301234567890123456?lang=en"
             )
  end

  test "TikTok short links need a redirect" do
    for url <- [
          "https://vm.tiktok.com/ZMabc123/",
          "https://vt.tiktok.com/ZSabc123/",
          "https://www.tiktok.com/t/ZTabc123/",
          "https://m.tiktok.com/v/7301234567890123456.html"
        ] do
      assert {:short_link, ^url} = Canonicalize.parse(url)
    end
  end

  test "resolve/2 follows one redirect" do
    Req.Test.stub(:tiktok_short, fn conn ->
      conn
      |> Plug.Conn.put_resp_header(
        "location",
        "https://www.tiktok.com/@someone/video/7301234567890123456?_r=1"
      )
      |> Plug.Conn.send_resp(301, "")
    end)

    assert {:ok, %{platform_video_id: "7301234567890123456"}} =
             Canonicalize.resolve("https://vm.tiktok.com/ZMabc123/",
               plug: {Req.Test, :tiktok_short}
             )
  end

  test "resolve/2 reports a short link that leads nowhere" do
    Req.Test.stub(:tiktok_dead, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)

    assert {:error, "That TikTok link does not lead to a video."} =
             Canonicalize.resolve("https://vm.tiktok.com/ZMdead/", plug: {Req.Test, :tiktok_dead})
  end

  for {url, message} <- [
        {"https://www.youtube.com/@channel", "does not point to a video"},
        {"https://www.youtube.com/watch?v=short", "does not point to a video"},
        {"https://www.tiktok.com/@someone/live", "live links have no replay"},
        {"https://vimeo.com/123", "Only YouTube and TikTok"},
        {"not a url at all", "not a link"},
        {"ftp://youtube.com/watch?v=BUm39a7diTU", "not a link"}
      ] do
    test "rejects #{url}" do
      assert {:error, message} = Canonicalize.parse(unquote(url))
      assert message =~ unquote(message)
    end
  end
end
