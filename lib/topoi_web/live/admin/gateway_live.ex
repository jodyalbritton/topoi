defmodule TopoiWeb.Admin.GatewayLive do
  @moduledoc """
  `/admin/gateway`: the Airo connection (base URL, key, model aliases).
  The settings form is the next piece of work; this page holds its
  place in the admin shell.
  """
  use TopoiWeb, :live_view

  alias TopoiWeb.CompositeComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "AI gateway")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="gateway">
      <div class="space-y-6">
        <.header size="page">
          AI gateway
          <:subtitle>
            The Airo connection used for speaker naming, move tagging, and the pushback judge.
          </:subtitle>
        </.header>
        <CompositeComponents.empty_state icon="hero-cpu-chip" title="Not configured">
          The base URL, key, and model aliases will be set here.
        </CompositeComponents.empty_state>
      </div>
    </Layouts.admin>
    """
  end
end
