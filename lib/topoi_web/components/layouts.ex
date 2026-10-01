defmodule TopoiWeb.Layouts do
  @moduledoc """
  The two shells.

    * `app/1` — the public library: wordmark and the four ways in
      (debaters, topics, tags, schools). Search lives in the page body
      (home, `/search`), not the header. A reading column, left
      aligned, with room for a wiki-style side rail on detail pages.
    * `admin/1` — the workspace behind `/admin`: a dense sidebar shell
      for ingest, the review gates, and integration settings.

  Design notes, so later pages stay in the same voice: porcelain base,
  ink text, verdigris primary, plum as the second debate lane, ochre
  only for unanswered pushback. Familjen Grotesk for interface, Literata
  for reading prose. The memorable element is the timecode citation and
  the timeline strip (`TopoiWeb.DebateComponents`); everything around
  them stays quiet. No all-caps eyebrows, no arrows on buttons.
  """
  use TopoiWeb, :html

  alias TopoiWeb.SiteComponents

  embed_templates "layouts/*"

  @doc "Fallback meta description for pages that do not set one."
  def default_description do
    "How public debaters argue: openings, counters, and the pushback they avoid, each cited to the moment in the debate."
  end

  @public_nav [
    {"debaters", "Debaters", "/debaters"},
    {"topics", "Topics", "/topics"},
    {"tags", "Tags", "/tags"},
    {"schools", "Schools", "/schools"},
    {"about", "About", "/about"}
  ]

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :active_nav, :string, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :nav, @public_nav)

    ~H"""
    <div class="flex min-h-dvh flex-col">
      <header class="sticky top-0 z-40 border-b border-base-300 bg-base-100/95 backdrop-blur">
        <div class="mx-auto flex w-full max-w-6xl items-center gap-8 px-4 py-3 sm:px-6">
          <.link navigate={~p"/"} aria-label="Topoi home" class="shrink-0">
            <SiteComponents.wordmark />
          </.link>

          <nav aria-label="Library" class="hidden items-center gap-1 md:flex">
            <SiteComponents.nav_link
              :for={{key, label, path} <- @nav}
              navigate={path}
              active={@active_nav == key}
            >
              {label}
            </SiteComponents.nav_link>
          </nav>

          <div class="ml-auto flex items-center gap-1">
            <%= if @current_scope do %>
              <SiteComponents.nav_link
                :if={@current_scope.user.admin}
                navigate={~p"/admin"}
                icon="hero-squares-2x2"
              >
                Admin
              </SiteComponents.nav_link>
              <SiteComponents.nav_link
                navigate={~p"/users/settings"}
                active={@active_nav == "account"}
                icon="hero-user-circle"
              >
                {@current_scope.user.username}
              </SiteComponents.nav_link>
              <SiteComponents.nav_link href={~p"/users/log-out"} method="delete">
                Sign out
              </SiteComponents.nav_link>
            <% else %>
              <SiteComponents.nav_link navigate={~p"/users/log-in"} active={@active_nav == "sign_in"}>
                Sign in
              </SiteComponents.nav_link>
            <% end %>
            <JobyKit.CoreComponents.theme_toggle class="ml-2" />
          </div>
        </div>

        <nav
          aria-label="Library"
          class="mx-auto flex w-full max-w-6xl gap-1 overflow-x-auto px-3 pb-2 md:hidden"
        >
          <SiteComponents.nav_link
            :for={{key, label, path} <- @nav}
            navigate={path}
            active={@active_nav == key}
          >
            {label}
          </SiteComponents.nav_link>
        </nav>
      </header>

      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-base-300">
        <div class="mx-auto flex w-full max-w-6xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-6 text-sm text-base-content/60 sm:px-6">
          <SiteComponents.wordmark size="sm" />
          <span class="ml-auto">© {Date.utc_today().year} Topoi</span>
        </div>
      </footer>

      <JobyKit.CoreComponents.flash_group flash={@flash} />
    </div>
    """
  end

  @admin_nav [
    {"overview", "Overview", "/admin", "hero-home"},
    {"gateway", "AI gateway", "/admin/gateway", "hero-cpu-chip"}
  ]

  attr :flash, :map, required: true
  attr :current_scope, :map, required: true
  attr :active_nav, :string, default: nil
  slot :inner_block, required: true

  def admin(assigns) do
    assigns = assign(assigns, :nav, @admin_nav)

    ~H"""
    <div class="min-h-dvh md:grid md:grid-cols-[15rem_1fr]">
      <aside class="border-b border-base-300 bg-base-200/50 md:sticky md:top-0 md:flex md:h-dvh md:flex-col md:border-r md:border-b-0">
        <div class="flex items-center justify-between gap-2 px-4 py-4">
          <.link navigate={~p"/admin"} class="flex items-baseline gap-2">
            <SiteComponents.wordmark size="sm" />
            <span class="text-sm text-base-content/60">admin</span>
          </.link>
        </div>

        <nav aria-label="Admin" class="flex gap-1 overflow-x-auto px-2 pb-3 md:flex-col md:pb-0">
          <SiteComponents.nav_link
            :for={{key, label, path, icon} <- @nav}
            variant="sidebar"
            navigate={path}
            icon={icon}
            active={@active_nav == key}
          >
            {label}
          </SiteComponents.nav_link>
        </nav>

        <div class="mt-auto hidden space-y-1 border-t border-base-300 px-2 py-3 md:block">
          <SiteComponents.nav_link variant="sidebar" navigate={~p"/"} icon="hero-globe-alt">
            View site
          </SiteComponents.nav_link>
          <SiteComponents.nav_link
            variant="sidebar"
            navigate={~p"/users/settings"}
            icon="hero-user-circle"
          >
            {@current_scope.user.username}
          </SiteComponents.nav_link>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm text-base-content/75 hover:bg-base-200"
          >
            <JobyKit.CoreComponents.icon
              name="hero-arrow-left-start-on-rectangle"
              class="size-4 opacity-70"
            /> Sign out
          </.link>
          <div class="px-3 pt-2"><JobyKit.CoreComponents.theme_toggle /></div>
        </div>
      </aside>

      <main class="min-w-0">
        <div class="mx-auto w-full max-w-5xl px-4 py-8 sm:px-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <JobyKit.CoreComponents.flash_group flash={@flash} />
    </div>
    """
  end
end
