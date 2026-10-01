defmodule TopoiWeb.VideoComponents do
  @moduledoc "Domain components for videos in the admin pipeline views."
  use TopoiWeb, :html

  @labels %{
    "submitted" => {"Queued", "neutral"},
    "transcribing" => {"Transcribing", "info"},
    "transcribed" => {"Transcribed", "info"},
    "normalized" => {"Turns ready", "ok"},
    "failed" => {"Failed", "danger"}
  }

  @doc "A video's pipeline status as a badge; the label names the state in plain words."
  attr :status, :string, values: Map.keys(@labels), required: true
  attr :rest, :global

  def status_badge(assigns) do
    {label, tone} = Map.fetch!(@labels, assigns.status)
    assigns = assign(assigns, label: label, tone: tone)

    ~H"""
    <span data-component="TopoiWeb.VideoComponents.status_badge" {@rest}>
      <.badge tone={@tone} class="whitespace-nowrap">{@label}</.badge>
    </span>
    """
  end
end
