defmodule TopoiWeb.SiteComponents do
  @moduledoc """
  Site chrome shared by the public shell and the admin shell: the
  wordmark, the header search box, and navigation links.

  Each follows the JobyKit wrapper contract (typed attrs,
  `data-component` on the root, `:rest` pass-through) and is registered
  in `TopoiWeb.DesignManifest`.
  """
  use TopoiWeb, :html

  alias JobyKit.CoreComponents

  @doc """
  The Topoi wordmark: the name plus a two-lane mark taken from the
  timeline strip (verdigris over plum), so the logo and the product's
  signature visual are the same object.
  """
  attr :size, :string, values: ~w(sm md), default: "md"
  attr :rest, :global

  def wordmark(assigns) do
    ~H"""
    <span
      data-component="TopoiWeb.SiteComponents.wordmark"
      class={[
        "inline-flex items-center font-semibold tracking-tight text-base-content",
        @size == "md" && "gap-2 text-xl",
        @size == "sm" && "gap-1.5 text-base"
      ]}
      {@rest}
    >
      <svg
        viewBox="0 0 20 14"
        aria-hidden="true"
        class={[@size == "md" && "h-3.5 w-5", @size == "sm" && "h-3 w-4"]}
      >
        <rect x="0" y="1" width="14" height="4" rx="2" class="fill-primary" />
        <rect x="6" y="9" width="14" height="4" rx="2" class="fill-secondary" />
      </svg>
      <span>topoi</span>
    </span>
    """
  end

  @doc """
  The library search box. A plain GET form to `/search`, so results
  pages are linkable and work without JavaScript. It sits in the page
  body (the home hero, the search page), not in the header.
  """
  attr :value, :string, default: nil
  attr :placeholder, :string, default: "Search debaters, topics, tags"
  attr :size, :string, values: ~w(md lg), default: "md"
  attr :autofocus, :boolean, default: false
  attr :rest, :global

  def search_box(assigns) do
    ~H"""
    <form
      data-component="TopoiWeb.SiteComponents.search_box"
      action={~p"/search"}
      method="get"
      role="search"
      {@rest}
    >
      <label class={[
        "input w-full gap-3 border-base-300 bg-base-200/50 focus-within:border-primary focus-within:bg-base-100",
        @size == "md" && "input-md",
        @size == "lg" && "input-lg h-14 rounded-xl text-base"
      ]}>
        <CoreComponents.icon
          name="hero-magnifying-glass"
          class={["opacity-60", @size == "md" && "size-4", @size == "lg" && "size-5"]}
        />
        <span class="sr-only">Search</span>
        <input
          type="search"
          name="q"
          value={@value}
          placeholder={@placeholder}
          autocomplete="off"
          autofocus={@autofocus}
          class="grow"
        />
      </label>
    </form>
    """
  end

  @doc """
  The page container: the content column every public page sits in,
  aligned with the header.
  """
  attr :rest, :global
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <div
      data-component="TopoiWeb.SiteComponents.page"
      class="mx-auto w-full max-w-6xl px-4 py-8 sm:px-6 sm:py-10"
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  A short text page (e.g. about): a title and a few paragraphs of
  reading prose in a measured column.
  """
  attr :title, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  def prose_page(assigns) do
    ~H"""
    <article data-component="TopoiWeb.SiteComponents.prose_page" {@rest}>
      <.page>
        <div class="max-w-[62ch] space-y-5">
          <JobyKit.CoreComponents.header size="page">{@title}</JobyKit.CoreComponents.header>
          <div class="space-y-4 font-serif text-lg leading-relaxed text-base-content/85">
            {render_slot(@inner_block)}
          </div>
        </div>
      </.page>
    </article>
    """
  end

  @doc "Secondary text: a detail or note beside primary content."
  attr :rest, :global
  slot :inner_block, required: true

  def secondary_text(assigns) do
    ~H"""
    <span
      data-component="TopoiWeb.SiteComponents.secondary_text"
      class="text-sm text-base-content/70"
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc "A muted secondary link (back links, \"All\" links)."
  attr :navigate, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  def quiet_link(assigns) do
    ~H"""
    <.link
      data-component="TopoiWeb.SiteComponents.quiet_link"
      navigate={@navigate}
      class="text-sm text-base-content/60 hover:text-base-content"
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  A one-line empty state: muted text, no icon, no box. For lists that
  have nothing in them yet.
  """
  attr :rest, :global
  slot :inner_block, required: true

  def empty_line(assigns) do
    ~H"""
    <p
      data-component="TopoiWeb.SiteComponents.empty_line"
      class="py-3 text-sm text-base-content/55"
      {@rest}
    >
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  A navigation link that marks itself current. Used in the public
  header and the admin sidebar. Pass `navigate` for a page, or `href`
  with `method` for an action such as signing out.
  """
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :method, :string, default: "get"
  attr :active, :boolean, default: false
  attr :variant, :string, values: ~w(header sidebar), default: "header"
  attr :icon, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <.link
      data-component="TopoiWeb.SiteComponents.nav_link"
      navigate={@navigate}
      href={@href}
      method={@method}
      aria-current={@active && "page"}
      class={[
        "inline-flex items-center gap-2 transition-colors",
        @variant == "header" &&
          "rounded-full px-3 py-1.5 text-sm font-medium text-base-content/70 hover:text-base-content",
        @variant == "header" && @active && "bg-base-200 text-base-content",
        @variant == "sidebar" &&
          "w-full rounded-lg px-3 py-2 text-sm text-base-content/75 hover:bg-base-200 hover:text-base-content",
        @variant == "sidebar" && @active && "bg-base-200 font-medium text-base-content"
      ]}
      {@rest}
    >
      <CoreComponents.icon :if={@icon} name={@icon} class="size-4 opacity-70" />
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
