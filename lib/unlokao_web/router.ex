defmodule UnlokaoWeb.Router do
  use UnlokaoWeb, :router

  import UnlokaoWeb.Autenticacao

  pipeline :api do
    plug :accepts, ["json"]
    plug :buscar_usuario_atual
  end

  pipeline :autenticado do
    plug :exigir_autenticacao
  end

  pipeline :admin do
    plug :exigir_autenticacao
    plug :exigir_admin
  end

  # Rotas públicas
  scope "/api", UnlokaoWeb do
    pipe_through :api

    post "/login", SessaoController, :create
    post "/senha/esqueci", SenhaController, :esqueci
    post "/senha/redefinir", SenhaController, :redefinir
  end

  # Qualquer usuário logado
  scope "/api", UnlokaoWeb do
    pipe_through [:api, :autenticado]

    post "/logout", SessaoController, :delete
    get "/me", ContaController, :show
    put "/me/senha", ContaController, :trocar_senha

    resources "/chaves", ChaveController, only: [:index, :show]
  end

  # Só administradores
  scope "/api", UnlokaoWeb do
    pipe_through [:api, :admin]

    resources "/chaves", ChaveController, only: [:create, :update, :delete]
    resources "/usuarios", UsuarioController, except: [:new, :edit]
  end
end
