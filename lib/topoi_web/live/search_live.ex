defmodule TopoiWeb.SearchLive do
  @moduledoc """
  `/search?q=…`. A GET URL so a search can be shared. Results arrive
  with published pages; until then it says what can be searched.
  """
  use TopoiWeb, :live_view

  alias TopoiWeb.SiteComponents

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(params, _uri, socket) do
    query = params |> Map.get("q", "") |> String.trim() |> String.slice(0, 200)

    {:noreply,
     assign(socket,
       query: query,
       page_title: if(query == "", do: "Search", else: "Search: #{query}"),
       page_description: "Search debaters, topics, and tags on Topoi."
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <SiteComponents.page>
        <h1 :if={@query == ""} class="sr-only">Search</h1>
        <SiteComponents.search_box value={@query} size="lg" autofocus={@query == ""} />
        <div :if={@query != ""} class="mt-10">
          <h1 class="border-b border-base-300 pb-2 font-semibold">Results for “{@query}”</h1>
          <SiteComponents.empty_line>Nothing published matches.</SiteComponents.empty_line>
        </div>
      </SiteComponents.page>
    </Layouts.app>
    """
  end
end
