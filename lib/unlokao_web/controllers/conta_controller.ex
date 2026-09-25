defmodule UnlokaoWeb.ContaController do
  @moduledoc "Dados e senha do próprio usuário logado."
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Unlokao.Autenticacao
  alias UnlokaoWeb.{ApiDoc, Schemas}

  action_fallback UnlokaoWeb.FallbackController

  tags(["Minha conta"])

  operation(:show,
    summary: "Dados do usuário logado",
    responses:
      [ok: ApiDoc.json("Usuário logado", Schemas.UsuarioResposta)] ++
        ApiDoc.erros([:nao_autenticado])
  )

  def show(conn, _params) do
    conn
    |> put_view(json: UnlokaoWeb.UsuarioJSON)
    |> render(:show, usuario: conn.assigns.usuario_atual)
  end

  operation(:trocar_senha,
    summary: "Troca a própria senha",
    description: "Encerra as outras sessões do usuário e mantém a atual.",
    request_body: ApiDoc.corpo(Schemas.TrocarSenhaEntrada),
    responses: [no_content: "Senha trocada"] ++ ApiDoc.erros([:nao_autenticado, :validacao])
  )

  def trocar_senha(conn, params) do
    %{usuario_atual: usuario, token_atual: token} = conn.assigns

    with {:ok, _usuario} <-
           Autenticacao.trocar_senha(usuario, params["senha_atual"], params, token) do
      send_resp(conn, :no_content, "")
    end
  end
end
