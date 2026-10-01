defmodule Topoi.Repo.Migrations.AddAdminToUsers do
  use Ecto.Migration

  # Admins run ingest and the review gates; other signed-in users will only
  # rate analysis as helpful (PRD §16).
  def change do
    alter table(:users) do
      add :admin, :boolean, null: false, default: false
    end
  end
end
