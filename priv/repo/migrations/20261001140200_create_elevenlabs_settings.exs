defmodule Topoi.Repo.Migrations.CreateElevenlabsSettings do
  use Ecto.Migration

  def change do
    create table(:elevenlabs_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :singleton, :boolean, null: false, default: true
      # Cloak-encrypted (Topoi.Encrypted.Binary).
      add :api_key, :binary
      add :model_id, :string, null: false, default: "scribe_v2"
      add :seed, :integer, null: false, default: 7

      timestamps(type: :utc_datetime)
    end

    create unique_index(:elevenlabs_settings, [:singleton])
    create constraint(:elevenlabs_settings, :singleton_true, check: "singleton = true")
  end
end
