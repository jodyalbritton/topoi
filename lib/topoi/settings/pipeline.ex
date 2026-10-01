defmodule Topoi.Settings.Pipeline do
  @moduledoc """
  Pipeline thresholds (PRD §9.1 turn rules, §9.5 K, §13 τ and the
  debater-page gate). One row; defaults apply until it is saved.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "pipeline_settings" do
    field :singleton, :boolean, default: true
    field :merge_gap_ms, :integer, default: 4_000
    field :backchannel_max_ms, :integer, default: 2_000
    field :backchannel_max_words, :integer, default: 6
    field :bridge_window_ms, :integer, default: 8_000
    field :pushback_window_turns, :integer, default: 6
    field :review_confidence_threshold, :float, default: 0.6
    field :debater_page_min_debates, :integer, default: 3

    timestamps(type: :utc_datetime)
  end

  @fields ~w(merge_gap_ms backchannel_max_ms backchannel_max_words bridge_window_ms
             pushback_window_turns review_confidence_threshold debater_page_min_debates)a

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> validate_number(:merge_gap_ms, greater_than_or_equal_to: 0)
    |> validate_number(:backchannel_max_ms, greater_than: 0)
    |> validate_number(:backchannel_max_words, greater_than: 0)
    |> validate_number(:bridge_window_ms, greater_than_or_equal_to: 0)
    |> validate_number(:pushback_window_turns, greater_than: 0)
    |> validate_number(:review_confidence_threshold,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:debater_page_min_debates, greater_than: 0)
    |> unique_constraint(:singleton)
  end
end
