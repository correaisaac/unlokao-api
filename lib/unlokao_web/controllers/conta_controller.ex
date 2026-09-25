defmodule UnlokaoWeb.ContaController do
  @moduledoc "Dados e senha do próprio usuário logado."
  use UnlokaoWeb, :controller

  alias Unlokao.Autenticacao

  action_fallback UnlokaoWeb.FallbackController

  def show(conn, _params) do
    conn
    |> put_view(json: UnlokaoWeb.UsuarioJSON)
    |> render(:show, usuario: conn.assigns.usuario_atual)
  end

  def trocar_senha(conn, params) do
    %{usuario_atual: usuario, token_atual: token} = conn.assigns

    with {:ok, _usuario} <-
           Autenticacao.trocar_senha(usuario, params["senha_atual"], params, token) do
      send_resp(conn, :no_content, "")
    end
  end
end
