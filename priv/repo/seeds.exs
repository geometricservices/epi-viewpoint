# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Epicenter.Repo.insert!(%Epicenter.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

if Application.get_env(:epicenter, :seeds_enabled?) do
  Epicenter.Release.seeds()
end
