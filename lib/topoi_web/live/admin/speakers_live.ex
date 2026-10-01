defmodule TopoiWeb.Admin.SpeakersLive do
  @moduledoc """
  Gate A (PRD §13): `/admin/debates/:id/speakers`. A form, one block per
  speaker label: who it is, their role, their side. Answers start from
  the suggestions and show why; the person confirming keeps or changes
  them and presses Confirm speakers.
  """
  use TopoiWeb, :live_view

  alias Topoi.{Debaters, Review, Speakers, Transcripts, Videos}
  alias Topoi.Workers
  alias TopoiWeb.{DebateComponents, SiteComponents, VideoComponents}

  @sample_turns 3

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Videos.subscribe()

    {:ok,
     socket
     |> assign(errors: %{}, page_title: "Speakers")
     |> load(id)
     |> reset_values()}
  end

  # Live updates refresh the surroundings but never overwrite answers
  # being edited.
  @impl true
  def handle_info({:video_updated, id}, %{assigns: %{video: %{id: id}}} = socket),
    do: {:noreply, load(socket, id)}

  def handle_info({:video_updated, _}, socket), do: {:noreply, socket}

  defp load(socket, id) do
    video = Videos.get_video!(id)
    transcript = Transcripts.live_transcript(video.id)

    assign(socket,
      video: video,
      transcript: transcript,
      form: Speakers.form(video.id),
      samples: samples_by_label(transcript),
      debaters: Debaters.list_debaters(),
      positions: Review.list_positions(),
      next_review: video.status == "speakers_confirmed" && Videos.next_needing_review(video.id)
    )
  end

  defp reset_values(socket) do
    form = socket.assigns.form

    assign(socket,
      values: %{
        "speakers" =>
          Map.new(form.speakers, fn s ->
            {s.label,
             %{
               "who" => s.who || "",
               "name" => s.name || "",
               "role" => s.role || "",
               "position" => s.position
             }}
          end),
        "facts" => %{
          "format" => form.facts.format || "",
          "channel_of_record" => form.facts.channel_of_record,
          "published_on" => form.facts.published_on || ""
        }
      }
    )
  end

  defp samples_by_label(nil), do: %{}

  defp samples_by_label(transcript) do
    transcript.id
    |> Transcripts.turns_with_text(100_000)
    |> Enum.filter(&(&1.kind == "substantive"))
    |> Enum.group_by(& &1.raw_label)
    |> Map.new(fn {label, turns} -> {label, Enum.take(turns, @sample_turns)} end)
  end

  @impl true
  def handle_event("change", params, socket) do
    {:noreply, assign(socket, values: Map.take(params, ["speakers", "facts"]), errors: %{})}
  end

  def handle_event("confirm", params, socket) do
    values = Map.take(params, ["speakers", "facts"])

    case Speakers.confirm(socket.assigns.video.id, values, socket.assigns.current_scope.user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(errors: %{})
         |> load(socket.assigns.video.id)
         |> reset_values()
         |> put_flash(:info, "Speakers confirmed.")}

      {:error, errors} ->
        {:noreply,
         socket
         |> assign(values: values, errors: errors)
         |> put_flash(:error, "Some answers need fixing; see the messages below.")}
    end
  end

  def handle_event("suggest_again", _params, socket) do
    case socket.assigns.transcript do
      nil ->
        {:noreply, put_flash(socket, :error, "This debate has no transcript yet.")}

      t ->
        {:ok, _} = Oban.insert(Workers.Participants.new(%{transcript_id: t.id}))

        {:noreply,
         put_flash(
           socket,
           :info,
           "Asking for new suggestions. Unconfirmed answers will update in a few seconds."
         )}
    end
  end

  # -- view helpers

  defp who_options(label, labels, debaters) do
    [{"Choose…", ""}] ++
      Enum.map(debaters, &{&1.name, "debater:" <> &1.id}) ++
      [{"Someone else (type their name)", "name"}] ++
      for(other <- labels, other != label, do: {"Same person as #{other}", "same:" <> other}) ++
      [{"Can't tell", "unknown"}]
  end

  defp role_options,
    do: [{"Choose…", ""} | Enum.map(Speakers.roles(), &{String.capitalize(&1), &1})]

  defp format_options, do: [{"Choose…", ""} | Enum.map(Speakers.formats(), &{humanize(&1), &1})]
  defp channel_options, do: Enum.map(Speakers.channels(), &{humanize(&1), &1})
  defp humanize(s), do: s |> String.replace("_", " ") |> String.capitalize()

  defp seek_url(%{platform: "youtube", canonical_url: url}, ms) when is_binary(url),
    do: url <> "&t=" <> Integer.to_string(div(ms, 1000)) <> "s"

  defp seek_url(_video, _ms), do: nil

  defp hint_lines(hints) do
    for {key, field} <- [who: "Who", role: "Role", position: "Side"],
        text = hints[key],
        do: {field, String.replace_prefix(text, "Suggested by ", "suggested by ")}
  end

  defp v(values, label, field), do: get_in(values, ["speakers", label, field]) || ""

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :labels, Enum.map(assigns.form.speakers, & &1.label))

    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} active_nav="debates">
      <div class="max-w-3xl space-y-8">
        <div class="space-y-2">
          <SiteComponents.quiet_link navigate={~p"/admin/debates/#{@video.id}"}>
            {@video.title || "Debate"}
          </SiteComponents.quiet_link>
          <.header size="page">
            Speakers
            <:actions><VideoComponents.status_badge status={@video.status} /></:actions>
          </.header>
        </div>

        <div
          :if={@video.status == "speakers_confirmed"}
          id="gate-done"
          class="space-y-1 rounded-box border border-success/40 px-4 py-3"
        >
          <p class="font-medium">Speakers confirmed. Nothing more to do here.</p>
          <SiteComponents.secondary_text>
            <%= if @next_review do %>
              Next to review: <.link
                navigate={~p"/admin/debates/#{@next_review.id}/speakers"}
                class="link"
              >
                {@next_review.title || @next_review.canonical_url || "a pasted debate"}
              </.link>.
            <% else %>
              No other debates need review.
            <% end %>
            You can still change answers below and confirm again.
          </SiteComponents.secondary_text>
        </div>

        <section
          :if={@video.status != "speakers_confirmed"}
          id="instructions"
          aria-label="How to confirm speakers"
          class="rounded-box border border-base-300 px-5 py-4"
        >
          <ol class="list-decimal space-y-1 pl-5">
            <li>
              Read each speaker's lines below. A timecode opens the video at that moment so you can listen.
            </li>
            <li>
              Check who each speaker is, their role, and their side. Answers are filled in from suggestions; change anything that is wrong.
            </li>
            <li>If one person appears under two labels, set the second to “Same person as …”.</li>
            <li>Check the debate's details at the bottom, then press Confirm speakers.</li>
          </ol>
        </section>

        <.form for={%{}} id="speakers-form" phx-change="change" phx-submit="confirm" class="space-y-8">
          <section
            :for={s <- @form.speakers}
            id={"speaker-#{s.label}"}
            class="space-y-3 border-t border-base-300 pt-6"
          >
            <.header level="h2">{s.label}</.header>

            <ol :if={@samples[s.label]} class="space-y-1 text-sm">
              <li :for={t <- @samples[s.label]} class="flex items-start gap-2">
                <div>
                  <DebateComponents.timecode
                    ms={t.start_ms}
                    href={seek_url(@video, t.start_ms)}
                    target="_blank"
                  />
                </div>
                <span class="font-serif text-base-content/80">{String.slice(t.text, 0, 240)}</span>
              </li>
            </ol>

            <% who = v(@values, s.label, "who") %>
            <div class="grid gap-x-4 gap-y-3 sm:grid-cols-3">
              <div class="space-y-1">
                <.input
                  name={"speakers[#{s.label}][who]"}
                  type="select"
                  label="Who is this?"
                  options={who_options(s.label, @labels, @debaters)}
                  value={who}
                />
              </div>
              <div :if={not String.starts_with?(who, "same:")}>
                <.input
                  name={"speakers[#{s.label}][role]"}
                  type="select"
                  label="Role"
                  options={role_options()}
                  value={v(@values, s.label, "role")}
                />
              </div>
              <div :if={not String.starts_with?(who, "same:")} class="space-y-1">
                <.input
                  name={"speakers[#{s.label}][position]"}
                  type="select"
                  label="Side"
                  options={Enum.map(@positions, &{&1.name, &1.slug})}
                  value={v(@values, s.label, "position")}
                />
              </div>
            </div>

            <ul :if={s.hints != %{}} class="space-y-0.5">
              <li :for={{field, text} <- hint_lines(s.hints)}>
                <SiteComponents.secondary_text>{field}: {text}</SiteComponents.secondary_text>
              </li>
            </ul>

            <.input
              :if={who == "name"}
              name={"speakers[#{s.label}][name]"}
              type="text"
              label="Name or handle"
              value={v(@values, s.label, "name")}
            />
            <SiteComponents.secondary_text :if={String.starts_with?(who, "same:")}>
              Takes the identity, role, and side of {String.replace_prefix(who, "same:", "")}.
            </SiteComponents.secondary_text>
            <p :if={@errors[s.label]} class="text-error">{@errors[s.label]}</p>
          </section>

          <section id="facts" class="space-y-3 border-t border-base-300 pt-6">
            <.header level="h2">This debate</.header>
            <div class="grid gap-x-4 gap-y-3 sm:grid-cols-3">
              <div class="space-y-1">
                <.input
                  name="facts[format]"
                  type="select"
                  label="Format"
                  options={format_options()}
                  value={@values["facts"]["format"]}
                />
                <SiteComponents.secondary_text :if={@form.facts.hints[:format]}>
                  {@form.facts.hints[:format]}
                </SiteComponents.secondary_text>
              </div>
              <div class="space-y-1">
                <.input
                  name="facts[channel_of_record]"
                  type="select"
                  label="Channel of record"
                  options={channel_options()}
                  value={@values["facts"]["channel_of_record"]}
                />
                <SiteComponents.secondary_text :if={@form.facts.hints[:channel_of_record]}>
                  {@form.facts.hints[:channel_of_record]}
                </SiteComponents.secondary_text>
              </div>
              <.input
                name="facts[published_on]"
                type="date"
                label="Published on"
                value={@values["facts"]["published_on"]}
              />
            </div>
            <p :if={@errors[:facts]} class="text-error">{@errors[:facts]}</p>
          </section>

          <div class="flex flex-wrap items-center gap-3 border-t border-base-300 pt-6">
            <.button variant="primary">Confirm speakers</.button>
            <.button type="button" variant="ghost" phx-click="suggest_again">
              Ask for new suggestions
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.admin>
    """
  end
end
