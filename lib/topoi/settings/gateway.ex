defmodule Topoi.Settings.Gateway do
  @moduledoc """
  The Airo gateway connection (PRD §7): base URL without `/v1`, an
  encrypted client key (write-only in the UI), and the model aliases
  used for chat and embeddings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "gateway_settings" do
    field :singleton, :boolean, default: true
    field :base_url, :string, default: "https://llm.local.joby.gg"
    field :api_key, Topoi.Encrypted.Binary, redact: true
    field :chat_model, :string, default: "chat"
    field :embedding_model, :string, default: "embed-fast"

    timestamps(type: :utc_datetime)
  end

  @doc "A blank `api_key` keeps the saved key."
  def changeset(settings, attrs) do
    attrs = drop_blank_key(attrs)

    settings
    |> cast(attrs, [:base_url, :api_key, :chat_model, :embedding_model])
    |> update_change(:base_url, &(&1 |> String.trim() |> String.trim_trailing("/")))
    |> update_change(:api_key, &String.trim/1)
    |> validate_required([:base_url, :chat_model, :embedding_model])
    |> validate_format(:base_url, ~r{^https?://[^\s/]+},
      message: "must start with http:// or https://"
    )
    |> unique_constraint(:singleton)
  end

  def configured?(%__MODULE__{api_key: key, base_url: url}),
    do: is_binary(key) and key != "" and is_binary(url) and url != ""

  defp drop_blank_key(%{} = attrs) do
    case Map.get(attrs, "api_key", Map.get(attrs, :api_key)) do
      blank when blank in [nil, ""] -> Map.drop(attrs, ["api_key", :api_key])
      _ -> attrs
    end
  end
end
