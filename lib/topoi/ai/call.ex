defmodule Topoi.AI.Call do
  @moduledoc "One logged gateway call (PRD §10: model and prompt version on every row)."
  use Topoi.Schema

  schema "llm_calls" do
    field :purpose, :string
    field :prompt_version, :string
    field :model, :string
    field :served_model, :string
    field :request, :map, default: %{}
    field :content, :string
    field :parsed, :map
    field :status, :string
    field :error, :string
    field :latency_ms, :integer
    belongs_to :video, Topoi.Videos.Video

    timestamps(updated_at: false)
  end
end
