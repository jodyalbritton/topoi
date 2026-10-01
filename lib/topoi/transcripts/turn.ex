defmodule Topoi.Transcripts.Turn do
  @moduledoc "Layer 2 (PRD §9.1): a turn built by the deterministic rules."
  use Topoi.Schema

  schema "turns" do
    field :idx, :integer
    field :raw_label, :string
    field :first_word_idx, :integer
    field :last_word_idx, :integer
    field :start_ms, :integer
    field :end_ms, :integer
    field :word_count, :integer
    field :kind, :string
    field :interrupted, :boolean, default: false

    belongs_to :transcript, Topoi.Transcripts.Transcript
  end
end
