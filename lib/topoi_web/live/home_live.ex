defmodule TopoiWeb.HomeLive do
  @moduledoc """
  The front page is a tool, not a pitch: search first, then what is in
  the library. What Topoi is lives on `/about`.
  """
  use TopoiWeb, :live_view

  alias TopoiWeb.SiteComponents

  # Each section lists its most recent published entries once the
  # pipeline publishes; until then each says so in one line.
  @sections [
    %{title: "Recent debates", path: "/debates", items: []},
    %{title: "Debaters", path: "/debaters", items: []},
    %{title: "Topics", path: "/topics", items: []},
    %{title: "Tags", path: "/tags", items: []}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Topoi",
       page_description: TopoiWeb.Layouts.default_description(),
       sections: @sections
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <SiteComponents.page>
        <h1 class="sr-only">Topoi</h1>
        <SiteComponents.search_box size="lg" autofocus />

        <div class="mt-10 grid gap-x-12 gap-y-10 md:grid-cols-2">
          <section :for={section <- @sections} aria-label={section.title}>
            <div class="flex items-baseline justify-between border-b border-base-300 pb-2">
              <h2 class="font-semibold">{section.title}</h2>
              <TopoiWeb.SiteComponents.quiet_link navigate={section.path}>
                All
              </TopoiWeb.SiteComponents.quiet_link>
            </div>
            <SiteComponents.empty_line :if={section.items == []}>
              None published yet.
            </SiteComponents.empty_line>
          </section>
        </div>
      </SiteComponents.page>
    </Layouts.app>
    """
  end
end
