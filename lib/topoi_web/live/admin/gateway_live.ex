defmodule TopoiWeb.Admin.GatewayLive do
  @moduledoc """
  `/admin/gateway`: the Airo connection used for speaker naming and,
  later, tagging (PRD §7). The key is write-only. "Test connection" uses
  the saved settings and lists the gateway's models by capability; after
  a successful test the model fields offer those ids.
  """
  use TopoiWeb, :live_view

  alias Topoi.AI.Gateway
  alias Topoi.Settings
  alias Topoi.Settings.Gateway, as: Config

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "AI gateway", models: nil, test_error: nil)
     |> assign_config(Settings.get(Config))}
  end

  defp assign_config(socket, config) do
    assign(socket, config: config, form: to_form(Settings.change(config), as: "gateway"))
  end

  @impl true
  def handle_event("save", %{"gateway" => params}, socket) do
    case Settings.update(Config, params) do
      {:ok, config} ->
        {:noreply, socket |> assign_config(config) |> put_flash(:info, "Gateway settings saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "gateway"))}
    end
  end

  def handle_event("test", _params, socket) do
    case Gateway.model_catalog(socket.assigns.config) do
      {:ok, catalog} ->
        {:noreply, assign(socket, models: Gateway.models_by_capability(catalog), test_error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, models: nil, test_error: describe(reason))}
    end
  end

  defp describe(:not_configured), do: "Save a base URL and key first."
  defp describe({:http, 401, _}), do: "The gateway rejected the key (401)."
  defp describe({:http, 403, _}), do: "The key is not allowed to list models (403)."
  defp describe({:http, status, _}), do: "The gateway answered with HTTP #{status}."
  defp describe({:transport, reason}), do: "Could not reach the gateway: #{inspect(reason)}."
  defp describe(other), do: "Connection failed: #{inspect(other)}."

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :key_saved?, is_binary(assigns.config.api_key))

    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="gateway">
      <div class="max-w-2xl space-y-8">
        <.header size="page">
          AI gateway
          <:subtitle>
            The Airo connection used for speaker naming, move tagging, and the pushback judge.
          </:subtitle>
        </.header>

        <.form for={@form} id="gateway-form" phx-submit="save" class="space-y-4">
          <.input
            field={@form[:base_url]}
            type="text"
            label="Base URL"
            placeholder="https://llm.local.joby.gg"
          />
          <div class="space-y-1">
            <.input
              name="gateway[api_key]"
              value=""
              type="password"
              label="Client key"
              autocomplete="off"
              placeholder={if @key_saved?, do: "Leave empty to keep the saved key"}
            />
            <TopoiWeb.SiteComponents.empty_line>
              {if @key_saved?, do: "A key is saved.", else: "No key saved."}
            </TopoiWeb.SiteComponents.empty_line>
          </div>

          <%= if @models do %>
            <.input
              field={@form[:chat_model]}
              type="select"
              label="Chat model"
              options={options(@models.chat, @form[:chat_model].value)}
            />
            <.input
              field={@form[:embedding_model]}
              type="select"
              label="Embedding model"
              options={options(@models.embeddings, @form[:embedding_model].value)}
            />
          <% else %>
            <.input field={@form[:chat_model]} type="text" label="Chat model" />
            <.input field={@form[:embedding_model]} type="text" label="Embedding model" />
          <% end %>

          <div class="flex flex-wrap gap-3">
            <.button variant="primary">Save gateway settings</.button>
            <.button type="button" variant="ghost" phx-click="test">Test connection</.button>
          </div>
        </.form>

        <p :if={@test_error} id="gateway-test-error" class="text-error">{@test_error}</p>
        <p :if={@models} id="gateway-test-ok" class="text-success">
          Connected. {length(@models.chat)} chat and {length(@models.embeddings)} embedding models available.
        </p>
      </div>
    </Layouts.admin>
    """
  end

  # Keep the saved value selectable even if the catalog no longer lists it.
  defp options(ids, current) do
    ids = if current in ids or current in [nil, ""], do: ids, else: [current | ids]
    Enum.map(ids, &{&1, &1})
  end
end
