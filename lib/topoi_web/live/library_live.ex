defmodule TopoiWeb.LibraryLive do
  @moduledoc """
  The library index pages: `/debaters`, `/debates`, `/topics`, `/tags`,
  `/schools`. One LiveView, one live action per section. Each lists
  published pages; until the pipeline publishes any, each says what
  will appear and when.
  """
  use TopoiWeb, :live_view

  alias TopoiWeb.SiteComponents

  @sections %{
    debaters: %{
      nav: "debaters",
      title: "Debaters",
      description: "Public debaters and how they argue."
    },
    debates: %{
      nav: nil,
      title: "Debates",
      description: "Every debate in the library, with what happened drawn over its length."
    },
    topics: %{
      nav: "topics",
      title: "Topics",
      description: "Arguments, each followed across everyone who runs it."
    },
    tags: %{
      nav: "tags",
      title: "Tags",
      description: "Moves and tactics, with examples from across the library."
    },
    schools: %{
      nav: "schools",
      title: "Schools",
      description: "Traditions, their stock questions, and the debaters who belong to them."
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    section = Map.fetch!(@sections, socket.assigns.live_action)

    {:ok,
     assign(socket,
       section: section,
       page_title: section.title,
       page_description: section.description
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_nav={@section.nav}>
      <SiteComponents.page>
        <div class="border-b border-base-300 pb-3">
          <.header size="page">{@section.title}</.header>
        </div>
        <SiteComponents.empty_line>None published yet.</SiteComponents.empty_line>
      </SiteComponents.page>
    </Layouts.app>
    """
  end
end
