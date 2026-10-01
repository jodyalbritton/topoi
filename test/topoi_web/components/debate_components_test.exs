defmodule TopoiWeb.DebateComponentsTest do
  use ExUnit.Case, async: true

  alias TopoiWeb.DebateComponents

  test "format_ms/1 formats minutes and hours" do
    assert DebateComponents.format_ms(0) == "0:00"
    assert DebateComponents.format_ms(194_000) == "3:14"
    assert DebateComponents.format_ms(5_430_000) == "1:30:30"
  end
end
