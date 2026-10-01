defmodule Topoi.Repo.Migrations.AddManualSpeakerFields do
  use Ecto.Migration

  # Gate A becomes a form (PRD §13): a speaker can be someone without a
  # debater record (typed name) or not identifiable, and the confirmation
  # records who confirmed and when.
  def change do
    alter table(:participants) do
      add :display_name, :string
      add :unidentified, :boolean, null: false, default: false
      add :confirmed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :confirmed_at, :utc_datetime
    end
  end
end
