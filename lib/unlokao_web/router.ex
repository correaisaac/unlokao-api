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

  pipeline :limite_login do
    plug UnlokaoWeb.LimiteDeTentativas, :login
  end

  pipeline :limite_esqueci_senha do
    plug UnlokaoWeb.LimiteDeTentativas, :esqueci_senha
  end

  # Rotas públicas
  scope "/api", UnlokaoWeb do
    pipe_through [:api, :limite_login]

    post "/login", SessaoController, :create
  end

  scope "/api", UnlokaoWeb do
    pipe_through [:api, :limite_esqueci_senha]

    post "/senha/esqueci", SenhaController, :esqueci
  end

  scope "/api", UnlokaoWeb do
    pipe_through :api

    post "/senha/redefinir", SenhaController, :redefinir
  end

  # Qualquer usuário logado
  scope "/api", UnlokaoWeb do
    pipe_through [:api, :autenticado]

    post "/logout", SessaoController, :delete
    get "/me", ContaController, :show
    put "/me/senha", ContaController, :trocar_senha
    get "/me/emprestimos", EmprestimoController, :meus

    resources "/chaves", ChaveController, only: [:index, :show]
  end

  # Só administradores
  scope "/api", UnlokaoWeb do
    pipe_through [:api, :admin]

    resources "/chaves", ChaveController, only: [:create, :update, :delete]
    resources "/usuarios", UsuarioController, except: [:new, :edit]

    resources "/emprestimos", EmprestimoController, only: [:index, :show, :create]
    post "/emprestimos/:id/devolucao", EmprestimoController, :devolver
  end
end
