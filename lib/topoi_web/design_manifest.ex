defmodule TopoiWeb.DesignManifest do
  @moduledoc """
  This app's component manifest. Backed by `JobyKit.Manifest`.

  This registers **this app's** components — the ones that surface on
  `/custom-designs`.

  JobyKit registers its own, so `/design` shows the kit inventory
  without anything being listed here, and picks up new kit components
  when you upgrade the dependency rather than when someone remembers to
  edit this file. `/design.json` combines the kit's entries and yours,
  so agents still get one source of truth.
  """

  use JobyKit.Manifest

  alias TopoiWeb.CompositeComponents
  alias TopoiWeb.DesignPreviews

  category(:composite,
    label: "Generic composites",
    description: "Multi-primitive patterns reused across domains."
  )

  category(:domain,
    label: "Domain composites",
    description: "Composites tied to a product area."
  )

  # ----------------------------------------------------------------- composite
  # `empty_state` is the worked example — a real composite that bundles
  # `<.icon>` + a heading + an optional action slot. Use it as the
  # template for your own: copy the attr / slot / data-component shape,
  # register the entry here, and add a preview in `design_previews.ex`.
  #
  # Generic composites belong in `TopoiWeb.CompositeComponents`;
  # domain-specific ones in their own module (e.g.
  # `TopoiWeb.ChatComponents`).

  component(CompositeComponents, :empty_state,
    category: :composite,
    summary: "Centered icon + title + optional action; fills empty containers.",
    preview: &DesignPreviews.empty_state_preview/1
  )

  component(TopoiWeb.SiteComponents, :wordmark,
    category: :composite,
    summary: "Topoi name plus the two-lane mark taken from the timeline strip.",
    preview: &DesignPreviews.wordmark_preview/1
  )

  component(TopoiWeb.SiteComponents, :search_box,
    category: :composite,
    summary: "Header search: a GET form to /search so results are linkable.",
    preview: &DesignPreviews.search_box_preview/1
  )

  component(TopoiWeb.SiteComponents, :page,
    category: :composite,
    summary: "The content column every public page sits in, aligned with the header.",
    preview: &DesignPreviews.page_preview/1
  )

  component(TopoiWeb.SiteComponents, :prose_page,
    category: :composite,
    summary: "Short text page: title plus reading prose in a measured column.",
    preview: &DesignPreviews.prose_page_preview/1
  )

  component(TopoiWeb.SiteComponents, :empty_line,
    category: :composite,
    summary: "One muted line for an empty list; no icon, no box.",
    preview: &DesignPreviews.empty_line_preview/1
  )

  component(TopoiWeb.SiteComponents, :nav_link,
    category: :composite,
    summary: "Navigation link that marks itself current; header and sidebar variants.",
    preview: &DesignPreviews.nav_link_preview/1
  )

  # -------------------------------------------------------------------- domain

  component(TopoiWeb.DebateComponents, :timecode,
    category: :domain,
    summary: "Timecode citation chip; every published claim ends in one.",
    preview: &DesignPreviews.timecode_preview/1
  )

  component(TopoiWeb.DebateComponents, :timeline_strip,
    category: :domain,
    summary: "A debate drawn as argument lines per participant, with unanswered pushback marked.",
    preview: &DesignPreviews.timeline_strip_preview/1
  )

  @doc """
  daisyUI primitives **this app** wraps that the kit does not.

  The kit declares its own, so there is nothing to list here until you
  wrap a primitive yourself — a `drawer`, say, or a `carousel`. Entries
  here flip that primitive to "Wrapped" in the catalogue on `/design`
  and link to your component. Ids must match `JobyKit.DaisyCatalogue`
  ids.

      def daisy_overrides do
        %{
          drawer: %{wrapper: "<.app_drawer>", anchor: "#jobykit-component-..."}
        }
      end
  """
  def daisy_overrides, do: %{}
end
