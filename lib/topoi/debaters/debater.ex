defmodule Topoi.Debaters.Debater do
  @moduledoc """
  A debater record (PRD §5). Can be created at any time; publication is
  gated separately (§13.1). `keyterms` feed transcription (§8.2).
  """
  use Topoi.Schema

  @slug_format ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/

  schema "debaters" do
    field :slug, :string
    field :name, :string
    field :handles, {:array, :string}, default: []
    field :keyterms, {:array, :string}, default: []

    timestamps()
  end

  def changeset(debater, attrs) do
    debater
    |> cast(attrs, [:slug, :name, :handles, :keyterms])
    |> validate_required([:slug, :name])
    |> update_change(:slug, &String.downcase/1)
    |> validate_format(:slug, @slug_format, message: "lowercase words joined by hyphens")
    |> validate_exclusion(:slug, Topoi.ReservedSlugs.all(), message: "is reserved")
    |> unique_constraint(:slug)
  end
end
