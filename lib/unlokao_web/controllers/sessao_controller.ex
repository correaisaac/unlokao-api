defmodule UnlokaoWeb.SessaoController do
  use UnlokaoWeb, :controller

  alias Unlokao.Autenticacao

  action_fallback UnlokaoWeb.FallbackController

  def create(conn, params) do
    with {:ok, usuario} <- Autenticacao.autenticar(params["email"], params["senha"]) do
      token = Autenticacao.criar_token_de_sessao(usuario)
      render(conn, :create, token: token, usuario: usuario)
    end
  end

  def delete(conn, _params) do
    Autenticacao.revogar_token_de_sessao(conn.assigns.token_atual)
    send_resp(conn, :no_content, "")
  end
end
