defmodule TopoiWeb.Admin.DebatesLive do
  @moduledoc """
  `/admin/debates`: submit a video link or paste a transcript (PRD §5,
  §8.1), and watch each video move through the pipeline. Updates arrive
  live from the workers.
  """
  use TopoiWeb, :live_view

  alias Topoi.{Debaters, Ingest, Videos}
  alias TopoiWeb.VideoComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Videos.subscribe()

    {:ok,
     socket
     |> assign(
       page_title: "Debates",
       mode: "link",
       debater_options: Enum.map(Debaters.list_debaters(), &{&1.name, &1.id}),
       videos: Videos.list_videos()
     )
     |> assign(
       link_form: to_form(%{"url" => "", "debater_ids" => [], "keyterms" => ""}, as: "link")
     )
     |> assign(
       paste_form: to_form(%{"text" => "", "url" => "", "debater_ids" => []}, as: "paste")
     )}
  end

  @impl true
  def handle_info({:video_updated, _id}, socket) do
    {:noreply, assign(socket, videos: Videos.list_videos())}
  end

  @impl true
  def handle_event("mode", %{"mode" => mode}, socket) when mode in ~w(link paste) do
    {:noreply, assign(socket, mode: mode)}
  end

  def handle_event("submit_link", %{"link" => params}, socket) do
    keyterms =
      params
      |> Map.get("keyterms", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    debater_ids = Map.get(params, "debater_ids", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    case Ingest.submit_url(params["url"] || "", debater_ids, keyterms) do
      {:ok, video} ->
        {:noreply,
         socket
         |> put_flash(:info, "Queued #{video.canonical_url}.")
         |> assign(
           link_form: to_form(%{"url" => "", "debater_ids" => [], "keyterms" => ""}, as: "link")
         )
         |> assign(videos: Videos.list_videos())}

      {:existing, video} ->
        {:noreply,
         push_navigate(socket, to: ~p"/admin/debates/#{video.id}")
         |> put_flash(:info, "Already in the library.")}

      {:error, message} ->
        {:noreply,
         socket |> put_flash(:error, message) |> assign(link_form: to_form(params, as: "link"))}
    end
  end

  def handle_event("submit_paste", %{"paste" => params}, socket) do
    debater_ids = Map.get(params, "debater_ids", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    case Ingest.submit_paste(params["text"] || "", params["url"], debater_ids) do
      {:ok, video} ->
        {:noreply,
         push_navigate(socket, to: ~p"/admin/debates/#{video.id}")
         |> put_flash(:info, "Transcript saved.")}

      {:error, message} ->
        {:noreply,
         socket |> put_flash(:error, message) |> assign(paste_form: to_form(params, as: "paste"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="debates">
      <div class="space-y-10">
        <.header size="page">Debates</.header>

        <section aria-labelledby="add-heading" class="max-w-2xl space-y-4">
          <div class="flex items-center justify-between gap-4">
            <.header id="add-heading" level="h2">Add a debate</.header>
            <div class="join" role="group" aria-label="How to add">
              <.button
                size="sm"
                variant={if @mode == "link", do: "neutral", else: "ghost"}
                phx-click="mode"
                phx-value-mode="link"
                class="join-item"
              >
                Video link
              </.button>
              <.button
                size="sm"
                variant={if @mode == "paste", do: "neutral", else: "ghost"}
                phx-click="mode"
                phx-value-mode="paste"
                class="join-item"
              >
                Paste transcript
              </.button>
            </div>
          </div>

          <.form
            :if={@mode == "link"}
            for={@link_form}
            id="link-form"
            phx-submit="submit_link"
            class="space-y-4"
          >
            <.input
              field={@link_form[:url]}
              type="text"
              label="YouTube or TikTok link"
              placeholder="https://www.youtube.com/watch?v=…"
            />
            <TopoiWeb.CompositeComponents.checkbox_group
              name="link[debater_ids]"
              label="Expected debaters"
              options={@debater_options}
              selected={List.wrap(@link_form[:debater_ids].value)}
              empty="No debaters yet. Add them under Debaters."
            />
            <.input
              field={@link_form[:keyterms]}
              type="text"
              label="Extra terms"
              placeholder="Comma-separated names or terms the speech will contain"
            />
            <.button variant="primary">Transcribe</.button>
          </.form>

          <.form
            :if={@mode == "paste"}
            for={@paste_form}
            id="paste-form"
            phx-submit="submit_paste"
            class="space-y-4"
          >
            <.input
              field={@paste_form[:text]}
              type="textarea"
              rows="10"
              label="Transcript"
              placeholder="00:00:00,300 --> 00:00:02,080 [Speaker 0]&#10;Everybody, welcome in."
            />
            <.input field={@paste_form[:url]} type="text" label="Video link (optional)" />
            <TopoiWeb.CompositeComponents.checkbox_group
              name="paste[debater_ids]"
              label="Expected debaters"
              options={@debater_options}
              selected={List.wrap(@paste_form[:debater_ids].value)}
              empty="No debaters yet. Add them under Debaters."
            />
            <.button variant="primary">Save transcript</.button>
          </.form>
        </section>

        <section aria-labelledby="videos-heading" class="space-y-3">
          <.header id="videos-heading" level="h2">In the pipeline</.header>
          <TopoiWeb.SiteComponents.empty_line :if={@videos == []}>
            No debates yet.
          </TopoiWeb.SiteComponents.empty_line>
          <.table
            :if={@videos != []}
            id="videos"
            rows={@videos}
            row_click={fn v -> JS.navigate(~p"/admin/debates/#{v.id}") end}
          >
            <:col :let={v} label="Debate">
              <span class="font-medium">{v.title || v.canonical_url || "Pasted transcript"}</span>
            </:col>
            <:col :let={v} label="Debaters">{Enum.map_join(v.debaters, ", ", & &1.name)}</:col>
            <:col :let={v} label="Status"><VideoComponents.status_badge status={v.status} /></:col>
            <:col :let={v} label="Note">
              <TopoiWeb.SiteComponents.secondary_text>
                {v.last_error}
              </TopoiWeb.SiteComponents.secondary_text>
            </:col>
          </.table>
        </section>
      </div>
    </Layouts.admin>
    """
  end
end
