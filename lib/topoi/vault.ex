defmodule Topoi.Vault do
  @moduledoc """
  Cloak vault for secrets at rest (integration API keys in settings
  rows, PRD §7). Keys: `config/test.exs` (static), `config/dev.exs`
  fallback overridden by the gitignored `config/dev.secret.exs`, and
  `CLOAK_KEY` in production (`config/runtime.exs`).
  """
  use Cloak.Vault, otp_app: :topoi
end

defmodule Topoi.Encrypted.Binary do
  @moduledoc "Ecto type for an encrypted string column (`:binary` in the DB)."
  use Cloak.Ecto.Binary, vault: Topoi.Vault
end
