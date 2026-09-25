# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :unlokao,
  ecto_repos: [Unlokao.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :unlokao, UnlokaoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: UnlokaoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Unlokao.PubSub,
  live_view: [signing_salt: "QTCH1H5R"]

# E-mails: em dev só aparecem no log. Em prod, trocar o adapter
# pelo provedor escolhido (ver https://hexdocs.pm/swoosh).
config :unlokao, Unlokao.Mailer, adapter: Swoosh.Adapters.Logger
config :swoosh, :api_client, false

config :unlokao,
  email_remetente: {"Unlokao", "nao-responda@unlokao.local"},
  # Página do front que recebe `?token=...` para redefinir a senha
  url_redefinir_senha: "http://localhost:5173/redefinir-senha",
  # Prazo de devolução quando o empréstimo é registrado sem `prazo`
  prazo_padrao_em_horas: 4

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
