defmodule UnlokaoWeb.SaudeController do
  @moduledoc "Health check para a hospedagem saber se a API está no ar (#27)."
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias UnlokaoWeb.{ApiDoc, Schemas}

  tags(["Infra"])

  operation(:show,
    summary: "Health check",
    description: "200 quando a API e o banco de dados estão respondendo.",
    security: [],
    responses: [
      ok: ApiDoc.json("No ar", Schemas.Saude),
      service_unavailable: ApiDoc.json("Banco de dados fora do ar", Schemas.Erro)
    ]
  )

  def show(conn, _params) do
    case Ecto.Adapters.SQL.query(Unlokao.Repo, "SELECT 1", []) do
      {:ok, _} ->
        json(conn, %{status: "ok"})

      {:error, _} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{errors: %{detail: "banco de dados indisponível"}})
    end
  end
end
