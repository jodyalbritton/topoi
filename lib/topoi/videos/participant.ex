defmodule Topoi.Videos.Participant do
  @moduledoc """
  A raw speaker label in one video (PRD §9.2). Several labels may share a
  `participant_id` when they are one person. Naming, roles, positions,
  and confirmation arrive with Gate A (stage 3).
  """
  use Topoi.Schema

  schema "participants" do
    field :raw_label, :string
    field :participant_id, :binary_id
    field :role, :string
    field :position, :string
    field :confidence, :float
    field :evidence_quote, :string
    field :confirmed_by_user, :boolean, default: false

    belongs_to :video, Topoi.Videos.Video
    belongs_to :debater, Topoi.Debaters.Debater

    timestamps()
  end
end
