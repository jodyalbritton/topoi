defmodule TopoiWeb.AboutLive do
  @moduledoc "`/about`: what Topoi is, in a few sentences."
  use TopoiWeb, :live_view

  alias TopoiWeb.SiteComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "About",
       page_description: TopoiWeb.Layouts.default_description()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_nav="about">
      <SiteComponents.prose_page title="About Topoi">
        <p>
          Topoi is a reference library of how public debaters argue: what they open with, how they answer a challenge, and which pushback they leave unanswered.
        </p>
        <p>
          Everything here comes from recorded public debates. Each finding links to the moment in the video it rests on, and nothing is published without one.
        </p>
        <p>
          A debater gets a page once three of their debates have been reviewed.
        </p>
      </SiteComponents.prose_page>
    </Layouts.app>
    """
  end
end
