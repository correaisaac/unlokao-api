defmodule UnlokaoWeb.AutorizacaoController do
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias Unlokao.Chaves
  alias Unlokao.Chaves.Autorizacao
  alias UnlokaoWeb.{ApiDoc, Schemas}

  action_fallback UnlokaoWeb.FallbackController

  tags(["Chaves"])

  @chave_id [
    chave_id: [
      in: :path,
      schema: %Schema{type: :string, format: :uuid},
      description: "Id da chave"
    ]
  ]

  operation(:index,
    summary: "Lista quem pode retirar uma chave",
    description: "Admin ou guarda. Só vale para a retirada quando a chave é `restrita`.",
    parameters:
      @chave_id ++
        ApiDoc.paginacao(
          usuario_id:
            ApiDoc.filtro("Só a autorização deste usuário", %Schema{type: :string, format: :uuid})
        ),
    responses:
      [ok: ApiDoc.json("Autorizações", Schemas.AutorizacaoLista)] ++
        ApiDoc.erros_admin([:nao_encontrado, :validacao])
  )

  def index(conn, %{"chave_id" => chave_id} = params) do
    with {:ok, chave} <- Chaves.fetch_chave(chave_id),
         {:ok, pagina} <- Chaves.list_autorizacoes(chave, params) do
      render(conn, :index, pagina: pagina)
    end
  end

  operation(:create,
    summary: "Adiciona uma pessoa à lista da chave",
    description: "Só admin. A pessoa precisa já estar cadastrada.",
    parameters: @chave_id,
    request_body: ApiDoc.corpo(Schemas.AutorizacaoEntrada),
    responses:
      [created: ApiDoc.json("Autorização criada", Schemas.AutorizacaoResposta)] ++
        ApiDoc.erros_admin([:nao_encontrado, :conflito, :validacao])
  )

  def create(conn, %{"chave_id" => chave_id} = params) do
    with {:ok, chave} <- Chaves.fetch_chave(chave_id),
         {:ok, %Autorizacao{} = autorizacao} <-
           Chaves.autorizar(chave, params, conn.assigns.usuario_atual) do
      conn
      |> put_status(:created)
      |> render(:show, autorizacao: autorizacao)
    end
  end

  operation(:delete,
    summary: "Remove uma pessoa da lista da chave",
    description: "Só admin. Quem já está com a chave continua com ela até devolver.",
    parameters: @chave_id ++ ApiDoc.id("Id da autorização"),
    responses: [no_content: "Removida"] ++ ApiDoc.erros_admin([:nao_encontrado])
  )

  def delete(conn, %{"chave_id" => chave_id, "id" => id}) do
    with {:ok, chave} <- Chaves.fetch_chave(chave_id),
         {:ok, %Autorizacao{}} <- Chaves.remover_autorizacao(chave, id) do
      send_resp(conn, :no_content, "")
    end
  end
end
