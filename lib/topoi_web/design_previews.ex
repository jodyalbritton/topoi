defmodule TopoiWeb.DesignPreviews do
  @moduledoc """
  Preview functions for **this app's** components, referenced by
  `TopoiWeb.DesignManifest`.

  The kit's own components are previewed by `JobyKit.Previews`, so
  `/design` shows the same examples in every JobyKit app. You only write
  previews for what you add.

  Each public function takes `assigns` (typically `%{}`) and returns a
  small HEEx rendering the component with sensible defaults. The
  manifest registers these via `preview: &TopoiWeb.DesignPreviews.X_preview/1`,
  and `JobyKit.SignatureComponent` invokes them inside the per-component
  card's collapsible Preview section.

  Naming convention: every preview function ends in `_preview` so they
  don't collide with the imported component functions of the same name
  (e.g. `button` vs `button_preview`).

  The previews call `JobyKit.CoreComponents` directly via the
  `CoreComponents` alias so the rendered HTML matches what the manifest
  declares — no dependency on the host's `<App>Web.CoreComponents`
  resolution.
  """

  use TopoiWeb, :html

  alias JobyKit.CoreComponents
  alias TopoiWeb.CompositeComponents

  def empty_state_preview(assigns) do
    ~H"""
    <div class="grid gap-4 sm:grid-cols-2">
      <CompositeComponents.empty_state icon="hero-inbox" title="No messages yet">
        Start a conversation with a teammate to see it here.
        <:action>
          <CoreComponents.button variant="primary">New message</CoreComponents.button>
        </:action>
      </CompositeComponents.empty_state>
      <CompositeComponents.empty_state
        icon="hero-sparkles"
        title="Set up your workspace"
        tone="primary"
      >
        Connect your first integration to populate this dashboard.
      </CompositeComponents.empty_state>
    </div>
    """
  end

  alias TopoiWeb.DebateComponents
  alias TopoiWeb.SiteComponents

  def wordmark_preview(assigns) do
    ~H"""
    <div class="flex items-center gap-6">
      <SiteComponents.wordmark />
      <SiteComponents.wordmark size="sm" />
    </div>
    """
  end

  def search_box_preview(assigns) do
    ~H"""
    <SiteComponents.search_box class="max-w-sm" />
    """
  end

  def page_preview(assigns) do
    ~H"""
    <SiteComponents.page class="border border-dashed border-base-300">
      Page content
    </SiteComponents.page>
    """
  end

  def prose_page_preview(assigns) do
    ~H"""
    <SiteComponents.prose_page title="About Topoi">
      <p>A reference library of how public debaters argue.</p>
    </SiteComponents.prose_page>
    """
  end

  def empty_line_preview(assigns) do
    ~H"""
    <SiteComponents.empty_line>None published yet.</SiteComponents.empty_line>
    """
  end

  def nav_link_preview(assigns) do
    ~H"""
    <div class="flex flex-wrap items-start gap-8">
      <div class="flex gap-1">
        <SiteComponents.nav_link navigate="#" active>Debaters</SiteComponents.nav_link>
        <SiteComponents.nav_link navigate="#">Topics</SiteComponents.nav_link>
      </div>
      <div class="w-56 space-y-1">
        <SiteComponents.nav_link navigate="#" variant="sidebar" icon="hero-home" active>
          Overview
        </SiteComponents.nav_link>
        <SiteComponents.nav_link navigate="#" variant="sidebar" icon="hero-cpu-chip">
          AI gateway
        </SiteComponents.nav_link>
      </div>
    </div>
    """
  end

  def timecode_preview(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-1.5">
      <DebateComponents.timecode ms={194_000} href="#" />
      <DebateComponents.timecode ms={1_285_000} href="#" />
      <DebateComponents.timecode ms={5_430_000} />
    </div>
    """
  end

  def timeline_strip_preview(assigns) do
    ~H"""
    <div class="max-w-lg space-y-6">
      <DebateComponents.timeline_strip
        duration_ms={3_360_000}
        lanes={[
          %{label: "Debater A", bands: [{55_000, 380_000}, {1_640_000, 2_190_000}], ticks: [349_000]},
          %{label: "Debater B", bands: [{180_000, 360_000}, {2_200_000, 2_880_000}], ticks: []}
        ]}
      />
      <DebateComponents.timeline_strip
        size="sm"
        labels={false}
        duration_ms={3_360_000}
        lanes={[
          %{label: "Debater A", bands: [{55_000, 380_000}, {1_640_000, 2_190_000}]},
          %{label: "Debater B", bands: [{180_000, 360_000}, {2_200_000, 2_880_000}]}
        ]}
      />
    </div>
    """
  end
end
