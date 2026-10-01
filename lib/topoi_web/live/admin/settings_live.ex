defmodule TopoiWeb.Admin.SettingsLive do
  @moduledoc """
  `/admin/settings`: transcription (ElevenLabs) and pipeline thresholds.
  The API key is write-only: the form never renders it back.
  """
  use TopoiWeb, :live_view

  alias Topoi.Settings
  alias Topoi.Settings.ElevenLabs
  alias Topoi.Settings.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Settings")
     |> assign_elevenlabs(Settings.get(ElevenLabs))
     |> assign_pipeline(Settings.get(Pipeline))}
  end

  defp assign_elevenlabs(socket, settings) do
    assign(socket,
      elevenlabs: settings,
      elevenlabs_form: to_form(Settings.change(settings), as: "elevenlabs")
    )
  end

  defp assign_pipeline(socket, settings) do
    assign(socket,
      pipeline: settings,
      pipeline_form: to_form(Settings.change(settings), as: "pipeline")
    )
  end

  @impl true
  def handle_event("save_elevenlabs", %{"elevenlabs" => params}, socket) do
    case Settings.update(ElevenLabs, params) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> assign_elevenlabs(settings)
         |> put_flash(:info, "Transcription settings saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, elevenlabs_form: to_form(changeset, as: "elevenlabs"))}
    end
  end

  def handle_event("save_pipeline", %{"pipeline" => params}, socket) do
    case Settings.update(Pipeline, params) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> assign_pipeline(settings)
         |> put_flash(:info, "Pipeline settings saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, pipeline_form: to_form(changeset, as: "pipeline"))}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :key_saved?, ElevenLabs.configured?(assigns.elevenlabs))

    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="settings">
      <div class="max-w-2xl space-y-12">
        <.header size="page">Settings</.header>

        <section aria-labelledby="transcription-heading" class="space-y-4">
          <.header id="transcription-heading" level="h2">
            Transcription
            <:subtitle>ElevenLabs speech-to-text.</:subtitle>
          </.header>

          <.form
            for={@elevenlabs_form}
            id="elevenlabs-form"
            phx-submit="save_elevenlabs"
            class="space-y-4"
          >
            <div class="space-y-1">
              <.input
                name="elevenlabs[api_key]"
                value=""
                type="password"
                label="API key"
                autocomplete="off"
                placeholder={if @key_saved?, do: "Leave empty to keep the saved key"}
              />
              <p class="text-sm text-base-content/60">
                <%= if @key_saved? do %>
                  A key is saved.
                <% else %>
                  No key saved.
                <% end %>
              </p>
            </div>
            <.input field={@elevenlabs_form[:model_id]} type="text" label="Model" />
            <.input field={@elevenlabs_form[:seed]} type="number" label="Seed" />
            <.button variant="primary">Save transcription settings</.button>
          </.form>
        </section>

        <section aria-labelledby="pipeline-heading" class="space-y-4">
          <.header id="pipeline-heading" level="h2">
            Pipeline
            <:subtitle>Turn rules and review thresholds. Times in milliseconds.</:subtitle>
          </.header>

          <.form
            for={@pipeline_form}
            id="pipeline-form"
            phx-submit="save_pipeline"
            class="grid gap-x-6 gap-y-4 sm:grid-cols-2"
          >
            <.input
              field={@pipeline_form[:merge_gap_ms]}
              type="number"
              label="Merge same-speaker gap"
            />
            <.input
              field={@pipeline_form[:bridge_window_ms]}
              type="number"
              label="Bridge across backchannel within"
            />
            <.input
              field={@pipeline_form[:backchannel_max_ms]}
              type="number"
              label="Backchannel: shorter than"
            />
            <.input
              field={@pipeline_form[:backchannel_max_words]}
              type="number"
              label="Backchannel: at most words"
            />
            <.input
              field={@pipeline_form[:pushback_window_turns]}
              type="number"
              label="Pushback window (turns)"
            />
            <.input
              field={@pipeline_form[:review_confidence_threshold]}
              type="number"
              step="0.05"
              label="Review below confidence"
            />
            <.input
              field={@pipeline_form[:debater_page_min_debates]}
              type="number"
              label="Debates before a debater page"
            />
            <div class="sm:col-span-2">
              <.button variant="primary">Save pipeline settings</.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.admin>
    """
  end
end
