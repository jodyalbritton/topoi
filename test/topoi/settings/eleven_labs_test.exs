defmodule Topoi.Settings.ElevenLabsTest do
  use Topoi.DataCase, async: true

  alias Topoi.Settings
  alias Topoi.Settings.ElevenLabs

  test "the key is encrypted at rest" do
    {:ok, settings} = Settings.update(ElevenLabs, %{api_key: "sk_test_plaintext"})

    [[raw]] =
      Repo.query!("SELECT api_key FROM elevenlabs_settings WHERE id = $1", [
        Ecto.UUID.dump!(settings.id)
      ]).rows

    refute raw =~ "sk_test_plaintext"
    assert Settings.get(ElevenLabs).api_key == "sk_test_plaintext"
  end

  test "a blank key keeps the saved key" do
    {:ok, _} = Settings.update(ElevenLabs, %{api_key: "sk_keep"})
    {:ok, settings} = Settings.update(ElevenLabs, %{"api_key" => "", "seed" => "11"})

    assert settings.api_key == "sk_keep"
    assert settings.seed == 11
  end

  test "configured?/1" do
    refute ElevenLabs.configured?(Settings.get(ElevenLabs))
    {:ok, settings} = Settings.update(ElevenLabs, %{api_key: "sk_x"})
    assert ElevenLabs.configured?(settings)
  end

  test "inspect never shows the key" do
    {:ok, settings} = Settings.update(ElevenLabs, %{api_key: "sk_secret"})
    refute inspect(settings) =~ "sk_secret"
  end
end
