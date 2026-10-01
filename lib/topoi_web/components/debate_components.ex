defmodule TopoiWeb.DebateComponents do
  @moduledoc """
  Domain components for debates: the timecode citation chip and the
  timeline strip. Together they are the site's signature: every claim
  ends in a timecode (PRD §6, §13.3), and every debate is drawn as a
  strip of argument lines over its length (PRD §13.2, "What happened").
  """
  use TopoiWeb, :html

  @doc """
  A timecode citation chip. Links to `href` (a seek into the player,
  or the debate page at that moment); renders as plain text when no
  `href` is given.
  """
  attr :ms, :integer, required: true, doc: "Offset into the video in milliseconds."
  attr :href, :string, default: nil
  attr :rest, :global

  def timecode(assigns) do
    assigns = assign(assigns, :label, format_ms(assigns.ms))

    ~H"""
    <.link
      :if={@href}
      data-component="TopoiWeb.DebateComponents.timecode"
      href={@href}
      class="tabular inline-flex items-center rounded-full bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary hover:bg-primary/20"
      aria-label={"At #{@label}"}
      {@rest}
    >
      {@label}
    </.link>
    <span
      :if={!@href}
      data-component="TopoiWeb.DebateComponents.timecode"
      class="tabular inline-flex items-center rounded-full bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/70"
      {@rest}
    >
      {@label}
    </span>
    """
  end

  @doc """
  Formats a millisecond offset as `m:ss` or `h:mm:ss`.
  """
  def format_ms(ms) when is_integer(ms) and ms >= 0 do
    total = div(ms, 1000)
    {h, m, s} = {div(total, 3600), div(rem(total, 3600), 60), rem(total, 60)}
    pad = &String.pad_leading(Integer.to_string(&1), 2, "0")

    if h > 0, do: "#{h}:#{pad.(m)}:#{pad.(s)}", else: "#{m}:#{pad.(s)}"
  end

  @doc """
  The timeline strip: one lane per participant, argument lines drawn as
  bands over the debate's length. Ochre ticks mark pushback the
  challenged participant did not answer. Lane colours are verdigris and
  plum so neither side reads as "the good one".

  `lanes` is a list of maps: `%{label: "A", bands: [{start_ms, end_ms}],
  ticks: [ms]}`. Lanes beyond two reuse the neutral tone.
  """
  attr :duration_ms, :integer, required: true
  attr :lanes, :list, required: true
  attr :size, :string, values: ~w(sm md), default: "md"
  attr :labels, :boolean, default: true, doc: "Show lane labels to the left."
  attr :rest, :global

  def timeline_strip(assigns) do
    ~H"""
    <figure
      data-component="TopoiWeb.DebateComponents.timeline_strip"
      role="img"
      aria-label={strip_label(@lanes, @duration_ms)}
      class="w-full"
      {@rest}
    >
      <div class={[
        "grid items-center",
        @labels && "grid-cols-[auto_1fr] gap-x-3",
        @size == "md" && "gap-y-2",
        @size == "sm" && "gap-y-1"
      ]}>
        <%= for {lane, i} <- Enum.with_index(@lanes) do %>
          <span :if={@labels} class="max-w-28 truncate text-xs text-base-content/70">
            {lane.label}
          </span>
          <div class={[
            "relative w-full overflow-hidden rounded-full bg-base-200",
            @size == "md" && "h-3",
            @size == "sm" && "h-1.5"
          ]}>
            <span
              :for={{from, to} <- lane.bands}
              class={["topoi-strip-band absolute inset-y-0 rounded-full", lane_tone(i)]}
              style={"left: #{pct(from, @duration_ms)}%; width: #{max(pct(to - from, @duration_ms), 0.6)}%; animation-delay: #{i * 120}ms"}
            ></span>
            <span
              :for={at <- Map.get(lane, :ticks, [])}
              class="absolute inset-y-0 w-0.5 bg-accent"
              style={"left: #{pct(at, @duration_ms)}%"}
            ></span>
          </div>
        <% end %>
      </div>
    </figure>
    """
  end

  defp lane_tone(0), do: "bg-primary/80"
  defp lane_tone(1), do: "bg-secondary/80"
  defp lane_tone(_), do: "bg-base-content/40"

  defp pct(_ms, 0), do: 0
  defp pct(ms, duration), do: Float.round(ms / duration * 100, 3)

  defp strip_label(lanes, duration_ms) do
    lanes_text =
      Enum.map_join(lanes, "; ", fn lane ->
        "#{lane.label}: #{length(lane.bands)} lines, #{length(Map.get(lane, :ticks, []))} unanswered"
      end)

    "Timeline over #{format_ms(duration_ms)}. #{lanes_text}"
  end
end
