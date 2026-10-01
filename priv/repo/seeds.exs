# Seeds for development.
#
#     mix run priv/repo/seeds.exs
#
# Idempotent: creates the dev user once and skips it afterwards. Skips entirely
# outside of :dev so no other database gets a seeded account.
#
# The password is random and printed once to whoever runs this script; it is
# never stored in the repo. Change it at /users/settings after logging in.
#
# Seeds no integration settings: the Airo gateway is configured at
# /admin/gateway, never baked into the repo.

if Mix.env() == :dev do
  alias Topoi.{Accounts, Repo}
  alias Topoi.Accounts.User

  username = "jody"

  case Accounts.get_user_by_username(username) do
    nil ->
      password = :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)

      {:ok, user} = Accounts.register_user(%{username: username, password: password})

      user
      |> User.confirm_changeset()
      |> Ecto.Changeset.change(admin: true)
      |> Repo.update!()

      IO.puts("✓ Seeded dev user: #{username} / #{password}")

    %User{admin: false} = user ->
      user |> Ecto.Changeset.change(admin: true) |> Repo.update!()
      IO.puts("• Dev user #{username} already exists; made admin")

    %User{} ->
      IO.puts("• Dev user #{username} already exists; skipping")
  end
end
