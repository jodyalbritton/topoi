defmodule Topoi.Repo.Migrations.CreateLlmCallsSuggestionsPositions do
  use Ecto.Migration

  # PRD §6 "suggest, then confirm; never author", §10 (model and prompt
  # version on every row), §3.1 (positions vocabulary).
  def change do
    create table(:llm_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :purpose, :string, null: false
      add :prompt_version, :string, null: false
      add :model, :string
      add :served_model, :string
      add :request, :map, null: false, default: %{}
      add :content, :text
      add :parsed, :map
      # ok | not_configured | http_error | transport_error | invalid_json | invalid_shape
      add :status, :string, null: false
      add :error, :text
      add :latency_ms, :integer
      add :video_id, references(:videos, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:llm_calls, [:video_id])

    create table(:positions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :definition, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:positions, [:slug])

    create table(:suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all), null: false
      # nil for video-level kinds
      add :raw_label, :string
      # identity | position | merge | format | channel_of_record
      add :kind, :string, null: false
      # role, position slug, format, channel of record
      add :value, :string
      add :stated_name, :string
      add :debater_id, references(:debaters, type: :binary_id, on_delete: :nilify_all)
      add :merge_with_label, :string
      add :evidence_quote, :text
      add :evidence_ms, :integer
      add :confidence, :float
      # model | code
      add :source, :string, null: false
      add :llm_call_id, references(:llm_calls, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:suggestions, [:video_id, :kind])

    create table(:suggestion_decisions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :suggestion_id, references(:suggestions, type: :binary_id, on_delete: :delete_all),
        null: false

      # confirmed | rejected
      add :outcome, :string, null: false
      add :reason, :text
      add :decided_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:suggestion_decisions, [:suggestion_id])

    # Seed vocabulary (§3.1). Curated; extended per resolution type.
    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    for {slug, name, definition} <- [
          {"theist", "Theist", "Argues that God or gods exist."},
          {"atheist", "Atheist", "Argues that no god exists, or rejects the theist's case."},
          {"agnostic", "Agnostic", "Holds that the question cannot be or has not been settled."},
          {"deist", "Deist", "Argues for a creator that does not intervene."},
          {"undeclared", "Undeclared", "Takes no stated side in this debate."}
        ] do
      execute(
        "INSERT INTO positions (id, slug, name, definition, inserted_at, updated_at) VALUES (gen_random_uuid(), '#{slug}', '#{name}', '#{String.replace(definition, "'", "''")}', '#{now}', '#{now}')",
        "DELETE FROM positions WHERE slug = '#{slug}'"
      )
    end
  end
end
