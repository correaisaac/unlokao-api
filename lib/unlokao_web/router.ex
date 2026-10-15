defmodule UnlokaoWeb.Router do
  use UnlokaoWeb, :router

  import UnlokaoWeb.Autenticacao

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: UnlokaoWeb.ApiSpec
    plug :buscar_usuario_atual
  end

  pipeline :autenticado do
    plug :exigir_autenticacao
  end

  pipeline :guarita do
    plug :exigir_autenticacao
    plug :exigir_guarita
  end

  pipeline :admin do
    plug :exigir_autenticacao
    plug :exigir_admin
  end

  pipeline :documentacao do
    plug OpenApiSpex.Plug.PutApiSpec, module: UnlokaoWeb.ApiSpec
  end

  # Documentação (#25): especificação OpenAPI e Swagger UI
  scope "/api" do
    pipe_through :documentacao

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
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
    get "/health", SaudeController, :show
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

  # Guarita (admin ou guarda): entrega e recebe chaves. Consulta usuários para
  # identificar quem retira (pelo QR Code da carteirinha ou pela matrícula).
  scope "/api", UnlokaoWeb do
    pipe_through [:api, :guarita]

    resources "/usuarios", UsuarioController, only: [:index, :show]

    resources "/emprestimos", EmprestimoController, only: [:index, :show, :create]
    post "/emprestimos/:id/devolucao", EmprestimoController, :devolver
  end

  # Só administradores
  scope "/api", UnlokaoWeb do
    pipe_through [:api, :admin]

    resources "/chaves", ChaveController, only: [:create, :update, :delete]
    resources "/usuarios", UsuarioController, only: [:create, :update, :delete]
  end
end
