defmodule Topoi.Debaters do
  @moduledoc "Debater records."
  import Ecto.Query, warn: false

  alias Topoi.Debaters.Debater
  alias Topoi.Repo

  def list_debaters, do: Repo.all(from d in Debater, order_by: d.name)

  def get_debater!(id), do: Repo.get!(Debater, id)

  def create_debater(attrs), do: %Debater{} |> Debater.changeset(attrs) |> Repo.insert()

  def change_debater(%Debater{} = debater, attrs \\ %{}), do: Debater.changeset(debater, attrs)
end
