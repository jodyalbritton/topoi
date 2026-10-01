defmodule Topoi.Transcripts.Word do
  @moduledoc """
  Layer 0 (PRD §9): one timed word or audio event. Never rewritten;
  spans cite `idx`.
  """
  use Topoi.Schema

  schema "transcript_words" do
    field :idx, :integer
    field :text, :string
    field :kind, :string, default: "word"
    field :start_ms, :integer
    field :end_ms, :integer
    field :raw_label, :string
    field :logprob, :float

    belongs_to :transcript, Topoi.Transcripts.Transcript
  end
end
