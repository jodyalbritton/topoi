defmodule Topoi.Review.Decision do
  @moduledoc "A human's confirm or reject of one suggestion, with the reason for a rejection."
  use Topoi.Schema

  schema "suggestion_decisions" do
    field :outcome, :string
    field :reason, :string
    belongs_to :suggestion, Topoi.Review.Suggestion
    belongs_to :decided_by, Topoi.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [:suggestion_id, :outcome, :reason, :decided_by_id])
    |> validate_required([:suggestion_id, :outcome, :decided_by_id])
    |> validate_inclusion(:outcome, ~w(confirmed rejected))
    |> then(fn cs ->
      if get_field(cs, :outcome) == "rejected",
        do: validate_required(cs, [:reason], message: "say why it is wrong"),
        else: cs
    end)
    |> unique_constraint(:suggestion_id, message: "has already been decided")
  end
end
