defmodule UnlokaoWeb.SessaoController do
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Unlokao.Autenticacao
  alias UnlokaoWeb.{ApiDoc, Schemas}

  action_fallback UnlokaoWeb.FallbackController

  tags(["Autenticação"])

  operation(:create,
    summary: "Faz login",
    description:
      "Devolve o token de sessão, válido por 7 dias. Limite: 10 tentativas por minuto por IP.",
    security: [],
    request_body: ApiDoc.corpo(Schemas.LoginEntrada),
    responses:
      [ok: ApiDoc.json("Login feito", Schemas.LoginResposta)] ++
        ApiDoc.erros([:nao_autenticado, :muitas_tentativas])
  )

  def create(conn, params) do
    with {:ok, usuario} <- Autenticacao.autenticar(params["email"], params["senha"]) do
      token = Autenticacao.criar_token_de_sessao(usuario)
      render(conn, :create, token: token, usuario: usuario)
    end
  end

  operation(:delete,
    summary: "Faz logout",
    description: "Encerra a sessão do token enviado.",
    responses: [no_content: "Sessão encerrada"] ++ ApiDoc.erros([:nao_autenticado])
  )

  def delete(conn, _params) do
    Autenticacao.revogar_token_de_sessao(conn.assigns.token_atual)
    send_resp(conn, :no_content, "")
  end
end
