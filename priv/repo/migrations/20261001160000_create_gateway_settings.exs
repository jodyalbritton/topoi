defmodule Topoi.Repo.Migrations.CreateGatewaySettings do
  use Ecto.Migration

  def change do
    create table(:gateway_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :singleton, :boolean, null: false, default: true
      add :base_url, :string, null: false, default: "https://llm.local.joby.gg"
      # Cloak-encrypted (Topoi.Encrypted.Binary).
      add :api_key, :binary
      add :chat_model, :string, null: false, default: "chat"
      add :embedding_model, :string, null: false, default: "embed-fast"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:gateway_settings, [:singleton])
    create constraint(:gateway_settings, :singleton_true, check: "singleton = true")
  end
end
