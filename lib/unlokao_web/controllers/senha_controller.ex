defmodule UnlokaoWeb.SenhaController do
  @moduledoc "Fluxo de \"esqueci minha senha\"."
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Unlokao.Autenticacao
  alias UnlokaoWeb.{ApiDoc, Schemas}

  action_fallback UnlokaoWeb.FallbackController

  tags(["Autenticação"])

  operation(:esqueci,
    summary: "Pede o link de redefinição de senha",
    description: """
    Sempre responde 204, exista ou não o e-mail. Se existir, envia um link
    válido por 1 hora. Limite: 5 pedidos por hora por IP.
    """,
    security: [],
    request_body: ApiDoc.corpo(Schemas.EsqueciSenhaEntrada),
    responses: [no_content: "Pedido recebido"] ++ ApiDoc.erros([:muitas_tentativas])
  )

  def esqueci(conn, params) do
    :ok = Autenticacao.solicitar_redefinicao_de_senha(params["email"], &url_de_redefinicao/1)
    send_resp(conn, :no_content, "")
  end

  operation(:redefinir,
    summary: "Redefine a senha com o token do e-mail",
    description: "O token é de uso único. Todas as sessões do usuário são encerradas.",
    security: [],
    request_body: ApiDoc.corpo(Schemas.RedefinirSenhaEntrada),
    responses: [no_content: "Senha redefinida"] ++ ApiDoc.erros([:validacao])
  )

  def redefinir(conn, params) do
    with {:ok, _usuario} <- Autenticacao.redefinir_senha(params["token"], params) do
      send_resp(conn, :no_content, "")
    end
  end

  defp url_de_redefinicao(token) do
    Application.fetch_env!(:unlokao, :url_redefinir_senha) <>
      "?" <> URI.encode_query(token: token)
  end
end
