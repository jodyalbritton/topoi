defmodule TopoiWeb.ReviewComponents do
  @moduledoc """
  Gate A components (PRD §6, §13): a suggestion with its evidence and the
  confirm / reject controls. Nothing here lets a reviewer type a label;
  they decide on what was suggested.
  """
  use TopoiWeb, :html

  alias TopoiWeb.DebateComponents

  @doc """
  One suggestion. Undecided: confirm, or reject with a reason. Decided:
  the outcome (and the reason for a rejection).
  """
  attr :suggestion, :map, required: true
  attr :rest, :global

  def suggestion_card(assigns) do
    ~H"""
    <div
      data-component="TopoiWeb.ReviewComponents.suggestion_card"
      id={"suggestion-#{@suggestion.id}"}
      class={[
        "space-y-2 rounded-box border p-4",
        decided_class(@suggestion.decision)
      ]}
      {@rest}
    >
      <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <p class="font-medium">{claim(@suggestion)}</p>
        <span class="text-xs text-base-content/55">
          {if @suggestion.source == "code", do: "Suggested by rule", else: "Suggested by model"}
        </span>
      </div>

      <%!-- Model evidence is quoted from the record; rule evidence is an
           explanation, so it is not shown in quotation marks. --%>
      <blockquote
        :if={@suggestion.evidence_quote && @suggestion.source == "model"}
        class="flex items-start gap-2 font-serif text-base-content/80"
      >
        <DebateComponents.timecode :if={@suggestion.evidence_ms} ms={@suggestion.evidence_ms} />
        <span>“{@suggestion.evidence_quote}”</span>
      </blockquote>
      <p
        :if={@suggestion.evidence_quote && @suggestion.source == "code"}
        class="flex items-start gap-2 text-sm text-base-content/75"
      >
        <DebateComponents.timecode :if={@suggestion.evidence_ms} ms={@suggestion.evidence_ms} />
        <span>{@suggestion.evidence_quote}</span>
      </p>

      <%= case @suggestion.decision do %>
        <% nil -> %>
          <div class="flex flex-wrap items-center gap-2 pt-1">
            <.button size="sm" variant="primary" phx-click="confirm" phx-value-id={@suggestion.id}>
              Confirm
            </.button>
            <.form
              for={%{}}
              as={:reject}
              id={"reject-#{@suggestion.id}"}
              phx-submit="reject"
              class="flex flex-1 items-center gap-2"
            >
              <input type="hidden" name="reject[id]" value={@suggestion.id} />
              <.input
                name="reject[reason]"
                value=""
                type="text"
                placeholder="Why is it wrong?"
                class="input input-sm min-w-48 flex-1"
              />
              <.button size="sm" variant="ghost">Reject</.button>
            </.form>
          </div>
        <% %{outcome: "confirmed"} -> %>
          <.badge tone="ok">Confirmed</.badge>
        <% %{outcome: "rejected", reason: reason} -> %>
          <div class="flex flex-wrap items-center gap-2 text-sm">
            <.badge tone="danger">Rejected</.badge>
            <span class="text-base-content/70">{reason}</span>
            <.button
              size="xs"
              variant="ghost"
              phx-click="reconsider"
              phx-value-id={@suggestion.id}
              class="ml-auto"
            >
              Reconsider
            </.button>
          </div>
      <% end %>
    </div>
    """
  end

  defp decided_class(nil), do: "border-warning/40 bg-base-100"
  defp decided_class(%{outcome: "confirmed"}), do: "border-base-300 bg-base-100"
  defp decided_class(_), do: "border-base-300 bg-base-200/40 opacity-70"

  @doc false
  def claim(%{kind: "identity"} = s) do
    who = s.debater && s.debater.name
    # With a linked debater the claim is the link; the stated name shows
    # only when nothing is linked (it stays in the evidence quote).
    name = !who && s.stated_name && "goes by “#{s.stated_name}”"

    [String.capitalize(s.value), who && "is #{who}", name]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  def claim(%{kind: "position", value: "undeclared"}), do: "No side stated"
  def claim(%{kind: "position", value: v}), do: "Argues as #{v}"
  def claim(%{kind: "merge", merge_with_label: other}), do: "Same person as #{other}"
  def claim(%{kind: "format", value: v}), do: "Format: #{String.replace(v, "_", " ")}"

  def claim(%{kind: "channel_of_record"} = s),
    do:
      "Channel of record: #{String.replace(s.value, "_", " ")}" <>
        if(s.debater, do: " (#{s.debater.name})", else: "")
end
