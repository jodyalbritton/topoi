defmodule Topoi.Repo.Migrations.AddObanAndPgvector do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 14)
    execute "CREATE EXTENSION IF NOT EXISTS vector"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS vector"
    Oban.Migration.down(version: 1)
  end
end
