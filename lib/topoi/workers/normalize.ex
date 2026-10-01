defmodule Topoi.Workers.Normalize do
  @moduledoc "Stage 2 (PRD §8): words → turns for one transcript."
  use Oban.Worker, queue: :normalize, max_attempts: 3

  alias Topoi.Repo
  alias Topoi.Transcripts.{Normalize, Transcript}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"transcript_id" => id}}) do
    case Repo.get(Transcript, id) do
      %Transcript{status: "received"} = t ->
        {:ok, _stats} = Normalize.run(t)

        # Stage 3 needs the AI gateway; without it the video waits at
        # "Turns ready" and can be proposed later from the admin page.
        if Topoi.AI.Gateway.configured?(),
          do: {:ok, _} = Oban.insert(Topoi.Workers.Participants.new(%{transcript_id: t.id}))

        :ok

      _ ->
        {:cancel, :transcript_not_received}
    end
  end
end
