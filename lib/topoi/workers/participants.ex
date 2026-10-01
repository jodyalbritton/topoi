defmodule Topoi.Workers.Participants do
  @moduledoc "Stage 3 (PRD §8): suggest who each speaker label is, for Gate A."
  use Oban.Worker,
    queue: :participants,
    max_attempts: 3,
    unique: [keys: [:transcript_id], period: 300]

  alias Topoi.Participants.Propose
  alias Topoi.Repo
  alias Topoi.Transcripts.Transcript

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"transcript_id" => id}}) do
    case Repo.get(Transcript, id) do
      %Transcript{status: "received"} = t ->
        case Propose.run(t) do
          {:ok, _} -> :ok
          {:error, :not_configured} -> {:cancel, :gateway_not_configured}
          {:error, status} -> {:error, status}
        end

      _ ->
        {:cancel, :transcript_not_received}
    end
  end
end
