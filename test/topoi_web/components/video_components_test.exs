defmodule TopoiWeb.VideoComponentsTest do
  use ExUnit.Case, async: true

  alias TopoiWeb.VideoComponents

  test "steps/1 marks done, review, running, failed, and waiting stages" do
    assert VideoComponents.steps("transcribing") ==
             [{"Transcribe", :running}, {"Build turns", :waiting}, {"Confirm speakers", :waiting}]

    assert VideoComponents.steps("speakers_suggested") ==
             [{"Transcribe", :done}, {"Build turns", :done}, {"Confirm speakers", :review}]

    assert VideoComponents.steps("speakers_confirmed") ==
             [{"Transcribe", :done}, {"Build turns", :done}, {"Confirm speakers", :done}]

    assert VideoComponents.steps("failed") ==
             [{"Transcribe", :failed}, {"Build turns", :waiting}, {"Confirm speakers", :waiting}]
  end
end
