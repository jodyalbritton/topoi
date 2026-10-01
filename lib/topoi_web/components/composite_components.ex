defmodule TopoiWeb.CompositeComponents do
  @moduledoc """
  Generic, multi-primitive composites for this app.

  Composites live one layer above core wrappers: they bundle a small set
  of `JobyKit.CoreComponents` primitives into a higher-level pattern that
  appears more than once across the app. Examples: empty states, page
  headers with breadcrumbs, callouts, hero blocks.

  Every composite follows the JobyKit wrapper contract:

    1. Declare every prop with `attr` (use `values:` for variant enums).
    2. Carry `data-component="TopoiWeb.CompositeComponents.<name>"`
       on the root element.
    3. Accept `attr :rest, :global` for id/class/aria-*/phx-* pass-through.
    4. Internals compose `JobyKit.CoreComponents` (or other registered
       wrappers) — never raw `<button>`/`<input>`/`<textarea>`.
    5. Register the composite in `TopoiWeb.DesignManifest`
       (`category: :composite`) so it surfaces on `/custom-designs` and
       in `/design.json`.

  The `empty_state/1` below ships pre-registered as a worked example.
  Use it as a template when you add your own composites: copy the
  attribute / slot / `data-component` shape, then register the new entry
  in the manifest.
  """

  use TopoiWeb, :html

  alias JobyKit.CoreComponents

  @doc """
  A group of checkboxes posting a list under one name (`name[]`), for
  choosing several items from a short list. An empty hidden value keeps
  the key present when nothing is checked.

      <.checkbox_group name="link[debater_ids]" label="Expected debaters"
        options={[{"Name", id}]} selected={[id]} />
  """
  attr :name, :string, required: true, doc: "Field name without the trailing []."
  attr :label, :string, required: true
  attr :options, :list, required: true, doc: "`{label, value}` tuples."
  attr :selected, :list, default: []
  attr :empty, :string, default: "Nothing to choose yet."
  attr :rest, :global

  def checkbox_group(assigns) do
    assigns = assign(assigns, :selected, Enum.map(assigns.selected, &to_string/1))

    ~H"""
    <fieldset data-component="TopoiWeb.CompositeComponents.checkbox_group" class="fieldset" {@rest}>
      <legend class="fieldset-legend">{@label}</legend>
      <input type="hidden" name={@name <> "[]"} value="" />
      <TopoiWeb.SiteComponents.empty_line :if={@options == []}>
        {@empty}
      </TopoiWeb.SiteComponents.empty_line>
      <div class="flex flex-wrap gap-x-6 gap-y-2">
        <label
          :for={{label, value} <- @options}
          class="flex cursor-pointer items-center gap-2 text-sm"
        >
          <input
            type="checkbox"
            name={@name <> "[]"}
            value={value}
            checked={to_string(value) in @selected}
            class="checkbox checkbox-sm"
          />
          {label}
        </label>
      </div>
    </fieldset>
    """
  end

  @doc """
  An empty-state callout: centered icon, title, supporting text, and an
  optional action slot. Use to fill an otherwise-empty container — an
  unfilled list, a search with no results, a fresh dashboard.

      <.empty_state icon="hero-inbox" title="No messages yet">
        Start a conversation with a teammate to see it here.
        <:action>
          <CoreComponents.button variant="primary">New message</CoreComponents.button>
        </:action>
      </.empty_state>
  """
  attr :icon, :string,
    default: "hero-sparkles",
    doc: "Heroicon name to display above the title."

  attr :title, :string, required: true
  attr :tone, :string, values: ~w(neutral primary), default: "neutral"
  attr :rest, :global

  slot :inner_block, doc: "Supporting copy beneath the title."
  slot :action, doc: "Optional call-to-action (typically a `<.button>`)."

  def empty_state(assigns) do
    ~H"""
    <div
      data-component="TopoiWeb.CompositeComponents.empty_state"
      class={[
        "flex flex-col items-center justify-center gap-3 rounded-2xl border border-dashed px-6 py-10 text-center",
        @tone == "neutral" && "border-base-300 bg-base-100/40 text-base-content/70",
        @tone == "primary" && "border-primary/30 bg-primary/5 text-base-content"
      ]}
      {@rest}
    >
      <span class={[
        "flex size-12 items-center justify-center rounded-full",
        @tone == "neutral" && "bg-base-200 text-base-content/60",
        @tone == "primary" && "bg-primary/10 text-primary"
      ]}>
        <CoreComponents.icon name={@icon} class="size-6" />
      </span>
      <h3 class="text-base font-semibold text-base-content">{@title}</h3>
      <div :if={@inner_block != []} class="max-w-sm text-sm text-base-content/65">
        {render_slot(@inner_block)}
      </div>
      <div :if={@action != []} class="pt-1">
        {render_slot(@action)}
      </div>
    </div>
    """
  end
end
