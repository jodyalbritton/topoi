defmodule Topoi.Review.Position do
  @moduledoc "A side a participant takes in one debate (PRD §3.1). Curated vocabulary."
  use Topoi.Schema

  schema "positions" do
    field :slug, :string
    field :name, :string
    field :definition, :string
    timestamps()
  end
end
