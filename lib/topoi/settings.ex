defmodule Topoi.Settings do
  @moduledoc """
  Singleton settings rows, edited in the admin UI (PRD §7: no env-var
  config). `get/1` returns the saved row or the schema's defaults;
  `update/2` inserts or updates the one row.
  """
  alias Topoi.Repo

  @doc "The saved row for `schema`, or a struct carrying its defaults."
  def get(schema) when is_atom(schema) do
    Repo.one(schema) || struct(schema)
  end

  @doc "A changeset for the settings form."
  def change(%schema{} = settings, attrs \\ %{}) do
    schema.changeset(settings, attrs)
  end

  @doc "Saves `attrs` into the one row for `schema`."
  def update(schema, attrs) when is_atom(schema) do
    schema
    |> get()
    |> schema.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
