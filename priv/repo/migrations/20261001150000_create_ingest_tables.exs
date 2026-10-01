defmodule Topoi.Repo.Migrations.CreateIngestTables do
  use Ecto.Migration

  # PRD §8.1, §9, §12.1: the tables for pipeline stages 1–2.
  def change do
    create table(:debaters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :citext, null: false
      add :name, :string, null: false
      add :handles, {:array, :string}, null: false, default: []
      add :keyterms, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:debaters, [:slug])

    create table(:videos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # youtube | tiktok | none (paste without a source URL)
      add :platform, :string, null: false
      add :platform_video_id, :string
      add :canonical_url, :string
      add :title, :string
      add :channel_name, :string
      add :channel_url, :string
      add :thumbnail_url, :string
      add :published_at, :utc_datetime
      add :duration_ms, :integer
      add :format, :string
      add :channel_of_record, :string, null: false, default: "unknown"
      # submitted | transcribing | transcribed | normalized | failed
      add :status, :string, null: false, default: "submitted"
      add :last_error, :text
      add :extra_keyterms, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    # One row per real video (PRD §8.1); pastes without a URL are exempt.
    create unique_index(:videos, [:platform, :platform_video_id],
             where: "platform <> 'none'",
             name: :videos_platform_video_id_index
           )

    create table(:video_debaters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all), null: false

      add :debater_id, references(:debaters, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:video_debaters, [:video_id, :debater_id])
    create index(:video_debaters, [:debater_id])

    create table(:transcripts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all), null: false
      # elevenlabs | paste
      add :provider, :string, null: false
      add :provider_job_id, :string
      # pending | received | failed | superseded
      add :status, :string, null: false, default: "pending"
      add :request_params, :map, null: false, default: %{}
      add :raw_payload, :map
      add :language_code, :string
      add :audio_duration_ms, :integer
      add :error, :text
      add :supersedes_id, references(:transcripts, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # At most one live transcript per video (PRD §12.1).
    create unique_index(:transcripts, [:video_id],
             where: "status IN ('pending', 'received')",
             name: :transcripts_one_live_per_video_index
           )

    create table(:transcript_words, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transcript_id, references(:transcripts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :idx, :integer, null: false
      add :text, :text, null: false
      # word | audio_event
      add :kind, :string, null: false, default: "word"
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :raw_label, :string
      add :logprob, :float
    end

    create unique_index(:transcript_words, [:transcript_id, :idx])

    create table(:turns, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transcript_id, references(:transcripts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :idx, :integer, null: false
      add :raw_label, :string, null: false
      add :first_word_idx, :integer, null: false
      add :last_word_idx, :integer, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :word_count, :integer, null: false
      # substantive | backchannel
      add :kind, :string, null: false
      add :interrupted, :boolean, null: false, default: false
    end

    create unique_index(:turns, [:transcript_id, :idx])

    create table(:participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all), null: false
      add :raw_label, :string, null: false
      # Shared by labels merged into one person (PRD §9.2); set at Gate A.
      add :participant_id, :binary_id
      add :role, :string
      add :position, :string
      add :debater_id, references(:debaters, type: :binary_id, on_delete: :nilify_all)
      add :confidence, :float
      add :evidence_quote, :text
      add :confirmed_by_user, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:participants, [:video_id, :raw_label])
    create index(:participants, [:debater_id])
  end
end
