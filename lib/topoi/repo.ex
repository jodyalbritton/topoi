defmodule Topoi.Repo do
  use Ecto.Repo,
    otp_app: :topoi,
    adapter: Ecto.Adapters.Postgres
end
