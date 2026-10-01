defmodule Topoi.SettingsTest do
  use Topoi.DataCase, async: true

  alias Topoi.Settings
  alias Topoi.Settings.Pipeline

  test "get/1 returns defaults before anything is saved" do
    settings = Settings.get(Pipeline)
    assert settings.id == nil
    assert settings.merge_gap_ms == 4_000
    assert settings.backchannel_max_words == 6
  end

  test "update/2 inserts once, then updates the same row" do
    {:ok, first} = Settings.update(Pipeline, %{merge_gap_ms: 3_000})
    {:ok, second} = Settings.update(Pipeline, %{bridge_window_ms: 9_000})

    assert first.id == second.id
    assert second.merge_gap_ms == 3_000
    assert second.bridge_window_ms == 9_000
    assert Repo.aggregate(Pipeline, :count) == 1
  end

  test "the database refuses a second row" do
    {:ok, _} = Settings.update(Pipeline, %{})

    assert {:error, changeset} = Repo.insert(Pipeline.changeset(%Pipeline{}, %{}))
    assert "has already been taken" in errors_on(changeset).singleton
  end

  test "validates ranges" do
    assert {:error, changeset} = Settings.update(Pipeline, %{review_confidence_threshold: 1.5})
    assert errors_on(changeset).review_confidence_threshold != []
  end
end
