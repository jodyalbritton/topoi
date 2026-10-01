defmodule Topoi.Review.Suggestion do
  @moduledoc """
  A suggested label with its evidence (PRD §6). Never edited: a human
  confirms or rejects it through a `Decision`.

  Kinds: `identity` (role + stated name + matched debater), `position`,
  `merge` (this label is the same person as `merge_with_label`),
  `format`, `channel_of_record`. `source` is `model` or `code`.
  """
  use Topoi.Schema

  @kinds ~w(identity position merge format channel_of_record)
  @roles ~w(host guest moderator opponent)

  schema "suggestions" do
    field :raw_label, :string
    field :kind, :string
    field :value, :string
    field :stated_name, :string
    field :merge_with_label, :string
    field :evidence_quote, :string
    field :evidence_ms, :integer
    field :confidence, :float
    field :source, :string
    field :superseded_at, :utc_datetime

    belongs_to :video, Topoi.Videos.Video
    belongs_to :debater, Topoi.Debaters.Debater
    belongs_to :llm_call, Topoi.AI.Call
    has_one :decision, Topoi.Review.Decision

    timestamps(updated_at: false)
  end

  def kinds, do: @kinds
  def roles, do: @roles

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [
      :video_id,
      :raw_label,
      :kind,
      :value,
      :stated_name,
      :debater_id,
      :merge_with_label,
      :evidence_quote,
      :evidence_ms,
      :confidence,
      :source,
      :llm_call_id
    ])
    |> validate_required([:video_id, :kind, :source])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:source, ~w(model code))
    |> validate_kind()
  end

  defp validate_kind(changeset) do
    case get_field(changeset, :kind) do
      "identity" ->
        changeset |> validate_required([:raw_label, :value]) |> validate_inclusion(:value, @roles)

      # "undeclared" has nothing to quote; any other side needs its quote.
      "position" ->
        if get_field(changeset, :value) == "undeclared",
          do: validate_required(changeset, [:raw_label, :value]),
          else: validate_required(changeset, [:raw_label, :value, :evidence_quote])

      "merge" ->
        validate_required(changeset, [:raw_label, :merge_with_label])

      _ ->
        validate_required(changeset, [:value])
    end
  end
end
