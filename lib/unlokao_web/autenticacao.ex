defmodule UnlokaoWeb.Autenticacao do
  @moduledoc """
  Plugs de autenticação usados no router.

  O cliente manda o token recebido no login no cabeçalho
  `Authorization: Bearer <token>`.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Unlokao.Autenticacao

  @doc "Coloca em `conn.assigns` o `:usuario_atual` (ou `nil`) e o `:token_atual`."
  def buscar_usuario_atual(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         %{} = usuario <- Autenticacao.buscar_usuario_por_token_de_sessao(token) do
      conn
      |> assign(:usuario_atual, usuario)
      |> assign(:token_atual, token)
    else
      _ -> assign(conn, :usuario_atual, nil)
    end
  end

  @doc "Bloqueia com 401 quem não está logado."
  def exigir_autenticacao(%{assigns: %{usuario_atual: %{}}} = conn, _opts), do: conn

  def exigir_autenticacao(conn, _opts) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "é preciso fazer login"}})
    |> halt()
  end

  @doc "Bloqueia com 403 quem não é admin. Use depois de `exigir_autenticacao`."
  def exigir_admin(%{assigns: %{usuario_atual: %{perfil: :admin}}} = conn, _opts), do: conn

  def exigir_admin(conn, _opts) do
    conn
    |> put_status(:forbidden)
    |> json(%{errors: %{detail: "acesso restrito a administradores"}})
    |> halt()
  end
end
