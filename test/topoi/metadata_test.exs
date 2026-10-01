defmodule Topoi.MetadataTest do
  use ExUnit.Case, async: true

  alias Topoi.Metadata

  @youtube %{
    platform: "youtube",
    platform_video_id: "BUm39a7diTU",
    canonical_url: "https://www.youtube.com/watch?v=BUm39a7diTU"
  }

  test "YouTube details from oEmbed, no publish date" do
    Req.Test.stub(:oembed_yt, fn conn ->
      assert conn.request_path == "/oembed"
      assert conn.query_params["url"] == @youtube.canonical_url

      Req.Test.json(conn, %{
        "title" => "Redeemed Zoomer + JesusandWhatnot",
        "author_name" => "Jesus and Whatnot",
        "author_url" => "https://www.youtube.com/@Jesus.andwhatnot",
        "thumbnail_url" => "https://i.ytimg.com/vi/BUm39a7diTU/hqdefault.jpg"
      })
    end)

    assert {:ok, attrs} = Metadata.fetch(@youtube, plug: {Req.Test, :oembed_yt})
    assert attrs.title == "Redeemed Zoomer + JesusandWhatnot"
    assert attrs.channel_name == "Jesus and Whatnot"
    refute Map.has_key?(attrs, :published_at)
  end

  test "TikTok details include the publish time from the id" do
    Req.Test.stub(:oembed_tt, fn conn ->
      Req.Test.json(conn, %{"title" => "t", "author_name" => "a", "author_url" => "u"})
    end)

    identity = %{
      platform: "tiktok",
      platform_video_id: "6718335390845095173",
      canonical_url: "https://www.tiktok.com/@scout2015/video/6718335390845095173"
    }

    assert {:ok, %{published_at: %DateTime{} = at}} =
             Metadata.fetch(identity, plug: {Req.Test, :oembed_tt})

    assert at.year == 2019
  end

  test "errors are returned, not raised" do
    Req.Test.stub(:oembed_404, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)
    assert {:error, {:http_status, 404}} = Metadata.fetch(@youtube, plug: {Req.Test, :oembed_404})
  end

  test "tiktok_published_at/1 ignores junk" do
    assert Metadata.tiktok_published_at("not-a-number") == nil
  end
end
