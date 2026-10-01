defmodule TopoiWeb.Admin.DebatersLive do
  @moduledoc """
  `/admin/debaters`: debater records (PRD §5). A record holds the name,
  handles, and the terms they use, which feed transcription keyterms.
  Schools, positions, and tags are never typed here (PRD §6).
  """
  use TopoiWeb, :live_view

  alias Topoi.Debaters
  alias Topoi.Debaters.Debater

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Debaters", debaters: Debaters.list_debaters())
     |> assign_form(Debaters.change_debater(%Debater{}))}
  end

  defp assign_form(socket, changeset), do: assign(socket, form: to_form(changeset, as: "debater"))

  @impl true
  def handle_event("validate", %{"debater" => params}, socket) do
    changeset =
      %Debater{} |> Debaters.change_debater(normalize(params)) |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"debater" => params}, socket) do
    case Debaters.create_debater(normalize(params)) do
      {:ok, debater} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added #{debater.name}.")
         |> assign(debaters: Debaters.list_debaters())
         |> assign_form(Debaters.change_debater(%Debater{}))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # Handles and terms are typed comma-separated; the slug defaults to the
  # name.
  defp normalize(params) do
    params
    |> Map.update("handles", [], &split/1)
    |> Map.update("keyterms", [], &split/1)
    |> Map.update("slug", "", fn
      "" -> slugify(params["name"] || "")
      slug -> slug
    end)
  end

  defp split(value) when is_binary(value),
    do: value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp split(value), do: value

  defp slugify(name),
    do: name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="debaters">
      <div class="space-y-10">
        <.header size="page">Debaters</.header>

        <section aria-labelledby="new-debater-heading" class="max-w-2xl space-y-4">
          <.header id="new-debater-heading" level="h2">Add a debater</.header>
          <.form
            for={@form}
            id="debater-form"
            phx-change="validate"
            phx-submit="save"
            class="grid gap-x-6 gap-y-4 sm:grid-cols-2"
          >
            <.input field={@form[:name]} type="text" label="Name" />
            <.input
              field={@form[:slug]}
              type="text"
              label="Page address"
              placeholder="Taken from the name if empty"
            />
            <.input
              name="debater[handles]"
              value={Enum.join(@form[:handles].value || [], ", ")}
              type="text"
              label="Handles"
              placeholder="Comma-separated"
            />
            <.input
              name="debater[keyterms]"
              value={Enum.join(@form[:keyterms].value || [], ", ")}
              type="text"
              label="Terms they use"
              placeholder="Comma-separated; sent with transcriptions"
            />
            <div class="sm:col-span-2">
              <.button variant="primary">Add debater</.button>
            </div>
          </.form>
        </section>

        <section aria-labelledby="debaters-heading" class="space-y-3">
          <.header id="debaters-heading" level="h2">All debaters</.header>
          <TopoiWeb.SiteComponents.empty_line :if={@debaters == []}>
            No debaters yet.
          </TopoiWeb.SiteComponents.empty_line>
          <.table :if={@debaters != []} id="debaters" rows={@debaters}>
            <:col :let={d} label="Name">{d.name}</:col>
            <:col :let={d} label="Address"><span class="text-base-content/70">/{d.slug}</span></:col>
            <:col :let={d} label="Handles">{Enum.join(d.handles, ", ")}</:col>
            <:col :let={d} label="Terms">{Enum.join(d.keyterms, ", ")}</:col>
          </.table>
        </section>
      </div>
    </Layouts.admin>
    """
  end
end
