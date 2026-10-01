defmodule Topoi.Repo.Migrations.AddSupersededAtToSuggestions do
  use Ecto.Migration

  # "Start over" on Gate A keeps history: old suggestions and their
  # decisions are marked superseded instead of deleted.
  def change do
    alter table(:suggestions) do
      add :superseded_at, :utc_datetime
    end

    create index(:suggestions, [:video_id],
             where: "superseded_at IS NULL",
             name: :suggestions_live_index
           )
  end
end
