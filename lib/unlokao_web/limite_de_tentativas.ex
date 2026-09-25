defmodule UnlokaoWeb.LimiteDeTentativas do
  @moduledoc """
  Plug que limita quantas vezes o mesmo IP pode chamar uma rota (#28).

      plug UnlokaoWeb.LimiteDeTentativas, :login

  Os limites ficam em `config :unlokao, :limites_de_tentativas`, como
  `acao: {maximo, janela_em_ms}`. Passou do limite: `429` com `Retry-After`.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(acao) when is_atom(acao), do: acao

  def call(conn, acao) do
    {maximo, janela_ms} =
      :unlokao |> Application.fetch_env!(:limites_de_tentativas) |> Keyword.fetch!(acao)

    chave = "#{acao}:#{:inet.ntoa(conn.remote_ip)}"

    case Unlokao.Limitador.hit(chave, janela_ms, maximo) do
      {:allow, _tentativas} ->
        conn

      {:deny, espera_ms} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(ceil(espera_ms / 1000)))
        |> put_status(:too_many_requests)
        |> json(%{errors: %{detail: "muitas tentativas; tente novamente mais tarde"}})
        |> halt()
    end
  end
end
