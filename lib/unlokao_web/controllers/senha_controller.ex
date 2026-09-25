defmodule UnlokaoWeb.SenhaController do
  @moduledoc "Fluxo de \"esqueci minha senha\"."
  use UnlokaoWeb, :controller

  alias Unlokao.Autenticacao

  action_fallback UnlokaoWeb.FallbackController

  def esqueci(conn, params) do
    :ok = Autenticacao.solicitar_redefinicao_de_senha(params["email"], &url_de_redefinicao/1)
    send_resp(conn, :no_content, "")
  end

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
