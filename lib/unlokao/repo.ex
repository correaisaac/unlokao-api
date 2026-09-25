defmodule Unlokao.Repo do
  use Ecto.Repo,
    otp_app: :unlokao,
    adapter: Ecto.Adapters.Postgres
end
