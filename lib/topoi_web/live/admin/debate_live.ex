defmodule TopoiWeb.Admin.DebateLive do
  @moduledoc "`/admin/debates/:id`: one video's details, transcript, speakers, and first turns."
  use TopoiWeb, :live_view

  alias Topoi.{Transcripts, Videos}
  alias TopoiWeb.{DebateComponents, VideoComponents}

  @preview_turns 30

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Videos.subscribe()
    {:ok, load(socket, id)}
  end

  @impl true
  def handle_info({:video_updated, id}, %{assigns: %{video: %{id: id}}} = socket),
    do: {:noreply, load(socket, id)}

  def handle_info({:video_updated, _}, socket), do: {:noreply, socket}

  defp load(socket, id) do
    video = Videos.get_video!(id)
    transcript = Transcripts.live_transcript(video.id)

    assign(socket,
      page_title: video.title || "Debate",
      video: video,
      transcript: transcript,
      word_count: transcript && Transcripts.count_words(transcript.id),
      turn_counts: (transcript && Transcripts.turn_counts(transcript.id)) || %{},
      turns: (transcript && Transcripts.turns_with_text(transcript.id, @preview_turns)) || [],
      participants: Videos.ensure_participants(video, [])
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="debates">
      <div class="space-y-10">
        <div class="space-y-2">
          <TopoiWeb.SiteComponents.quiet_link navigate={~p"/admin/debates"}>
            Debates
          </TopoiWeb.SiteComponents.quiet_link>
          <.header size="page">
            {@video.title || @video.canonical_url || "Pasted transcript"}
            <:subtitle>
              <span :if={@video.channel_name}>{@video.channel_name}</span>
            </:subtitle>
            <:actions>
              <div class="flex items-center gap-3">
                <VideoComponents.status_badge status={@video.status} />
                <.button
                  :if={@video.status in ~w(speakers_suggested speakers_confirmed)}
                  size="sm"
                  navigate={~p"/admin/debates/#{@video.id}/speakers"}
                  variant={if @video.status == "speakers_suggested", do: "primary", else: "ghost"}
                >
                  Review speakers
                </.button>
              </div>
            </:actions>
          </.header>
          <p :if={@video.last_error} class="text-sm text-error">{@video.last_error}</p>
        </div>

        <TopoiWeb.VideoComponents.pipeline_steps
          status={@video.status}
          review_path={~p"/admin/debates/#{@video.id}/speakers"}
        />

        <.list>
          <:item title="Video">
            <.link
              :if={@video.canonical_url}
              href={@video.canonical_url}
              target="_blank"
              rel="noopener"
              class="link"
            >
              {@video.canonical_url}
            </.link>
            <span :if={!@video.canonical_url}>No link</span>
          </:item>
          <:item title="Expected debaters">{Enum.map_join(@video.debaters, ", ", & &1.name)}</:item>
          <:item title="Length">
            {if @video.duration_ms,
              do: DebateComponents.format_ms(@video.duration_ms),
              else: "Unknown"}
          </:item>
          <:item title="Transcript">
            <%= if @transcript do %>
              {@transcript.provider}, {@transcript.status}, <span class="tabular">{@word_count}</span>
              words
            <% else %>
              None yet
            <% end %>
          </:item>
          <:item title="Turns">
            <span class="tabular">{Map.get(@turn_counts, "substantive", 0)}</span>
            substantive, <span class="tabular">{Map.get(@turn_counts, "backchannel", 0)}</span>
            backchannel
          </:item>
          <:item title="Speakers">{Enum.map_join(@participants, ", ", & &1.raw_label)}</:item>
        </.list>

        <section :if={@turns != []} aria-labelledby="turns-heading" class="space-y-3">
          <.header id="turns-heading" level="h2">First turns</.header>
          <ol class="divide-y divide-base-300 border-y border-base-300">
            <li
              :for={t <- @turns}
              class={[
                "grid gap-1 py-2 sm:grid-cols-[5rem_7rem_1fr] sm:gap-4",
                t.kind == "backchannel" && "text-base-content/50"
              ]}
            >
              <div><DebateComponents.timecode ms={t.start_ms} /></div>
              <span class="text-sm">{t.raw_label}</span>
              <span class="font-serif">
                {t.text}
                <span :if={t.interrupted} class="text-sm text-base-content/50">(interrupted)</span>
              </span>
            </li>
          </ol>
        </section>
      </div>
    </Layouts.admin>
    """
  end
end
