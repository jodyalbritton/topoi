defmodule Topoi.Ingest.Keyterms do
  @moduledoc """
  Keyterms sent with a transcription (PRD §8.2): expected debaters'
  names, handles, and terms; the channel name and name-like fragments of
  the title; free terms from the submit form. Deduplicated and held to
  the API limits (≤ 1000 terms, each < 50 characters and ≤ 5 words).
  """

  @max_terms 1000
  @max_chars 49
  @max_words 5

  @doc "Returns `{terms, dropped}`; `dropped` are terms over the limits."
  def build(debaters, video, extra \\ []) do
    candidates =
      Enum.flat_map(debaters, fn d -> [d.name | d.handles ++ d.keyterms] end) ++
        List.wrap(video.channel_name) ++
        title_fragments(video.title) ++
        extra

    {ok, dropped} =
      candidates
      |> Enum.map(&clean/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&String.downcase/1)
      |> Enum.split_with(&within_limits?/1)

    {Enum.take(ok, @max_terms), dropped}
  end

  # "Redeemed Zoomer + JesusandWhatnot |Catholicism & Modern Day Christianity|"
  # → ["Redeemed Zoomer", "JesusandWhatnot"]: the parts joined by + / vs / x /
  # & before any | or : section.
  defp title_fragments(nil), do: []

  defp title_fragments(title) do
    title
    |> String.split(~r/[|:]/, parts: 2)
    |> hd()
    |> String.split(~r/\s+(?:\+|vs\.?|x|&)\s+/i)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(String.length(&1) in 2..@max_chars))
  end

  defp clean(term), do: term |> to_string() |> String.replace(~r/\s+/, " ") |> String.trim()

  defp within_limits?(term) do
    String.length(term) <= @max_chars and length(String.split(term, " ")) <= @max_words
  end
end
