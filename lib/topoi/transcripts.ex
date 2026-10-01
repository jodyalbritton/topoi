defmodule Topoi.Transcripts do
  @moduledoc "Transcripts, their words (layer 0), and turns (layer 2)."
  import Ecto.Query, warn: false

  alias Topoi.Repo
  alias Topoi.Transcripts.{Transcript, Turn, Word}

  @chunk 2_000

  def create_transcript(attrs), do: %Transcript{} |> Transcript.changeset(attrs) |> Repo.insert()

  def update_transcript(%Transcript{} = t, attrs),
    do: t |> Transcript.changeset(attrs) |> Repo.update()

  @doc "The video's live (pending or received) transcript, or nil."
  def live_transcript(video_id) do
    Repo.one(
      from t in Transcript,
        where: t.video_id == ^video_id and t.status in ["pending", "received"]
    )
  end

  @doc """
  Stores parsed words for a transcript, replacing any stored before.
  `words` are maps with `:text`, `:kind`, `:start_ms`, `:end_ms`,
  `:raw_label`, and optional `:logprob`; `idx` is assigned in order.
  """
  def put_words(%Transcript{id: id}, words) do
    Repo.transaction(fn ->
      Repo.delete_all(from w in Word, where: w.transcript_id == ^id)

      words
      |> Enum.with_index()
      |> Enum.map(fn {w, i} ->
        %{
          id: Ecto.UUID.generate(),
          transcript_id: id,
          idx: i,
          text: w.text,
          kind: Map.get(w, :kind, "word"),
          start_ms: w.start_ms,
          end_ms: w.end_ms,
          raw_label: w.raw_label,
          logprob: Map.get(w, :logprob)
        }
      end)
      |> Enum.chunk_every(@chunk)
      |> Enum.reduce(0, fn chunk, acc ->
        {n, _} = Repo.insert_all(Word, chunk)
        acc + n
      end)
    end)
  end

  def list_words(transcript_id) do
    Repo.all(from w in Word, where: w.transcript_id == ^transcript_id, order_by: w.idx)
  end

  def count_words(transcript_id) do
    Repo.aggregate(from(w in Word, where: w.transcript_id == ^transcript_id), :count)
  end

  @doc "Replaces a transcript's turns. `turns` are maps; `idx` is assigned in order."
  def put_turns(%Transcript{id: id}, turns) do
    Repo.transaction(fn ->
      Repo.delete_all(from t in Turn, where: t.transcript_id == ^id)

      turns
      |> Enum.with_index()
      |> Enum.map(fn {t, i} ->
        t
        |> Map.take([
          :raw_label,
          :first_word_idx,
          :last_word_idx,
          :start_ms,
          :end_ms,
          :word_count,
          :kind,
          :interrupted
        ])
        |> Map.merge(%{id: Ecto.UUID.generate(), transcript_id: id, idx: i})
      end)
      |> Enum.chunk_every(@chunk)
      |> Enum.reduce(0, fn chunk, acc ->
        {n, _} = Repo.insert_all(Turn, chunk)
        acc + n
      end)
    end)
  end

  @doc """
  The first `limit` turns with their text: the turn speaker's words in
  the turn's range (a bridged turn's range can enclose the other side's
  backchannel words).
  """
  def turns_with_text(transcript_id, limit) do
    turns =
      Repo.all(
        from t in Turn, where: t.transcript_id == ^transcript_id, order_by: t.idx, limit: ^limit
      )

    case turns do
      [] ->
        []

      _ ->
        last = turns |> Enum.map(& &1.last_word_idx) |> Enum.max()

        words =
          Repo.all(
            from w in Word,
              where: w.transcript_id == ^transcript_id and w.idx <= ^last and w.kind == "word",
              order_by: w.idx
          )

        Enum.map(turns, fn t ->
          text =
            words
            |> Enum.filter(
              &(&1.idx >= t.first_word_idx and &1.idx <= t.last_word_idx and
                  &1.raw_label == t.raw_label)
            )
            |> Enum.map_join(" ", & &1.text)

          Map.put(t, :text, text)
        end)
    end
  end

  def list_turns(transcript_id) do
    Repo.all(from t in Turn, where: t.transcript_id == ^transcript_id, order_by: t.idx)
  end

  @doc ~S'Turn counts by kind: `%{"substantive" => n, "backchannel" => m}`.'
  def turn_counts(transcript_id) do
    from(t in Turn,
      where: t.transcript_id == ^transcript_id,
      group_by: t.kind,
      select: {t.kind, count()}
    )
    |> Repo.all()
    |> Map.new()
  end
end
