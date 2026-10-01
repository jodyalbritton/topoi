defmodule TopoiWeb.VideoComponents do
  @moduledoc "Domain components for videos in the admin pipeline views."
  use TopoiWeb, :html

  @labels %{
    "submitted" => {"Queued", "neutral"},
    "transcribing" => {"Transcribing", "info"},
    "transcribed" => {"Transcribed", "info"},
    "normalized" => {"Turns ready", "neutral"},
    "speakers_suggested" => {"Speakers to review", "warn"},
    "speakers_confirmed" => {"Speakers confirmed", "ok"},
    "failed" => {"Failed", "danger"}
  }

  # Stages this build runs, with the statuses at which each is done.
  @stages [
    {"Transcribe", ~w(transcribed normalized speakers_suggested speakers_confirmed)},
    {"Build turns", ~w(normalized speakers_suggested speakers_confirmed)},
    {"Confirm speakers", ~w(speakers_confirmed)}
  ]

  @doc """
  Where a video is in the pipeline (PRD §8): each stage is done, needs a
  person, is running, failed, or waiting. The last line names what comes
  after the stages this build has.
  """
  attr :status, :string, required: true
  attr :review_path, :string, default: nil, doc: "Link for the stage that needs a person."
  attr :rest, :global

  def pipeline_steps(assigns) do
    assigns = assign(assigns, :steps, steps(assigns.status))

    ~H"""
    <ol data-component="TopoiWeb.VideoComponents.pipeline_steps" class="space-y-1.5 text-sm" {@rest}>
      <li :for={{name, state} <- @steps} class="flex items-center gap-2">
        <JobyKit.CoreComponents.icon name={step_icon(state)} class={["size-4", step_tone(state)]} />
        <span class={state == :waiting && "text-base-content/50"}>{name}</span>
        <span :if={state == :review} class="text-base-content/70">
          needs your review.
          <.link :if={@review_path} navigate={@review_path} class="link">Review now</.link>
        </span>
        <span :if={state == :running} class="text-base-content/70">running</span>
        <span :if={state == :failed} class="text-error">failed</span>
      </li>
      <li class="flex items-center gap-2 text-base-content/50">
        <JobyKit.CoreComponents.icon name="hero-ellipsis-horizontal-circle" class="size-4" />
        Tag moves and find pushbacks (not built yet)
      </li>
    </ol>
    """
  end

  @doc false
  def steps(status) do
    {steps, _blocked} =
      Enum.map_reduce(@stages, false, fn {name, done_in}, blocked ->
        state =
          cond do
            status in done_in -> :done
            blocked -> :waiting
            status == "failed" -> :failed
            status == "speakers_suggested" -> :review
            true -> :running
          end

        {{name, state}, blocked or state != :done}
      end)

    steps
  end

  defp step_icon(:done), do: "hero-check-circle"
  defp step_icon(:review), do: "hero-exclamation-circle"
  defp step_icon(:running), do: "hero-arrow-path"
  defp step_icon(:failed), do: "hero-x-circle"
  defp step_icon(:waiting), do: "hero-minus-circle"

  defp step_tone(:done), do: "text-success"
  defp step_tone(:review), do: "text-warning"
  defp step_tone(:running), do: "text-info"
  defp step_tone(:failed), do: "text-error"
  defp step_tone(:waiting), do: "text-base-content/40"

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
