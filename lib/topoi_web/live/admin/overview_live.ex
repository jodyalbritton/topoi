defmodule TopoiWeb.Admin.OverviewLive do
  @moduledoc """
  `/admin`: what is set up and what is waiting. Each setup row reports
  real state, not a checklist of intentions.
  """
  use TopoiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    counts =
      Topoi.Videos.list_videos() |> Enum.frequencies_by(& &1.status)

    {:ok, assign(socket, page_title: "Admin", setup: setup_rows(), counts: counts)}
  end

  defp setup_rows do
    elevenlabs? =
      Topoi.Settings.ElevenLabs.configured?(Topoi.Settings.get(Topoi.Settings.ElevenLabs))

    [
      %{
        title: "Transcription",
        detail: "ElevenLabs speech-to-text.",
        ok: elevenlabs?,
        status: if(elevenlabs?, do: "Key saved", else: "No key"),
        path: ~p"/admin/settings"
      },
      %{
        title: "AI gateway",
        detail: "Airo, for speaker naming, tagging, and the pushback judge.",
        ok: false,
        status: "Not configured",
        path: ~p"/admin/gateway"
      },
      %{
        title: "Video details",
        detail:
          "Title and channel from oEmbed. Publish dates are entered when confirming speakers.",
        ok: true,
        status: "No key needed",
        path: nil
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="overview">
      <div class="space-y-10">
        <.header size="page">Overview</.header>

        <section aria-labelledby="setup-heading" class="space-y-3">
          <.header id="setup-heading" level="h2">Setup</.header>
          <ul class="divide-y divide-base-300 rounded-box border border-base-300">
            <li
              :for={row <- @setup}
              class="grid gap-1 px-4 py-3 sm:grid-cols-[12rem_1fr_auto] sm:items-center sm:gap-4"
            >
              <span class="font-medium">{row.title}</span>
              <span class="text-sm text-base-content/70">{row.detail}</span>
              <span class="flex items-center gap-3">
                <.badge tone={if row.ok, do: "ok", else: "warn"}>{row.status}</.badge>
                <.button :if={row.path} navigate={row.path} size="sm" variant="ghost">
                  Configure
                </.button>
              </span>
            </li>
          </ul>
        </section>

        <section aria-labelledby="debates-heading" class="space-y-3">
          <.header id="debates-heading" level="h2">Debates</.header>
          <TopoiWeb.SiteComponents.empty_line :if={@counts == %{}}>
            No debates yet. <.link navigate={~p"/admin/debates"} class="link">Add one</.link>.
          </TopoiWeb.SiteComponents.empty_line>
          <p :if={@counts != %{}} class="flex flex-wrap items-center gap-3 text-sm">
            <span :for={{status, n} <- @counts} class="flex items-center gap-1.5">
              <TopoiWeb.VideoComponents.status_badge status={status} />
              <span class="tabular">{n}</span>
            </span>
            <.link navigate={~p"/admin/debates"} class="link">All debates</.link>
          </p>
        </section>
      </div>
    </Layouts.admin>
    """
  end
end
