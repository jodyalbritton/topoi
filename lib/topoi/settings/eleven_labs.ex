defmodule Topoi.Settings.ElevenLabs do
  @moduledoc """
  ElevenLabs speech-to-text settings (PRD §8.2). The key is encrypted at
  rest and never rendered back to the form.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "elevenlabs_settings" do
    field :singleton, :boolean, default: true
    field :api_key, Topoi.Encrypted.Binary, redact: true
    field :model_id, :string, default: "scribe_v2"
    field :seed, :integer, default: 7

    timestamps(type: :utc_datetime)
  end

  @doc """
  A blank `api_key` in `attrs` keeps the saved key, so the form can leave
  the field empty without wiping it.
  """
  def changeset(settings, attrs) do
    attrs = drop_blank_key(attrs)

    settings
    |> cast(attrs, [:api_key, :model_id, :seed])
    |> update_change(:api_key, &String.trim/1)
    |> validate_required([:model_id, :seed])
    |> validate_number(:seed, greater_than_or_equal_to: 0, less_than_or_equal_to: 2_147_483_647)
    |> unique_constraint(:singleton)
  end

  @doc "True when a key has been saved."
  def configured?(%__MODULE__{api_key: key}), do: is_binary(key) and key != ""

  defp drop_blank_key(%{} = attrs) do
    case Map.get(attrs, "api_key", Map.get(attrs, :api_key)) do
      blank when blank in [nil, ""] -> Map.drop(attrs, ["api_key", :api_key])
      _ -> attrs
    end
  end
end
