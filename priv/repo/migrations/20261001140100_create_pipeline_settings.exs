defmodule Topoi.Repo.Migrations.CreatePipelineSettings do
  use Ecto.Migration

  # Singleton: at most one row, enforced by the unique index plus check.
  def change do
    create table(:pipeline_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :singleton, :boolean, null: false, default: true

      # Turn rules, PRD §9.1 (sized on the first sample; re-derived as
      # samples accumulate).
      add :merge_gap_ms, :integer, null: false, default: 4_000
      add :backchannel_max_ms, :integer, null: false, default: 2_000
      add :backchannel_max_words, :integer, null: false, default: 6
      add :bridge_window_ms, :integer, null: false, default: 8_000

      # Pushback window K and review threshold τ (PRD §9.5, §13).
      add :pushback_window_turns, :integer, null: false, default: 6
      add :review_confidence_threshold, :float, null: false, default: 0.6

      # Debater-page gate N (PRD §13.1).
      add :debater_page_min_debates, :integer, null: false, default: 3

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pipeline_settings, [:singleton])
    create constraint(:pipeline_settings, :singleton_true, check: "singleton = true")
  end
end
