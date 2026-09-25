defmodule UnlokaoWeb.ChaveController do
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias Unlokao.Chaves
  alias Unlokao.Chaves.Chave
  alias UnlokaoWeb.{ApiDoc, Schemas}

  action_fallback UnlokaoWeb.FallbackController

  tags(["Chaves"])

  operation(:index,
    summary: "Lista as chaves ativas",
    description: "Qualquer usuário logado.",
    parameters:
      ApiDoc.paginacao(
        status:
          ApiDoc.filtro("Status da chave", %Schema{
            type: :string,
            enum: Schemas.Base.status_chave()
          }),
        bloco: ApiDoc.filtro("Bloco (sem diferenciar maiúsculas)", %Schema{type: :string}),
        busca: ApiDoc.filtro("Procura no código e no espaço", %Schema{type: :string})
      ),
    responses:
      [ok: ApiDoc.json("Chaves", Schemas.ChaveLista)] ++
        ApiDoc.erros([:nao_autenticado, :validacao])
  )

  def index(conn, params) do
    with {:ok, pagina} <- Chaves.list_chaves(params) do
      render(conn, :index, pagina: pagina)
    end
  end

  operation(:create,
    summary: "Cadastra uma chave",
    description: "Só admin. Toda chave nasce `disponivel`.",
    request_body: ApiDoc.corpo(Schemas.ChaveEntrada),
    responses:
      [created: ApiDoc.json("Chave criada", Schemas.ChaveResposta)] ++
        ApiDoc.erros_admin([:conflito, :validacao])
  )

  def create(conn, params) do
    with {:ok, %Chave{} = chave} <- Chaves.create_chave(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/chaves/#{chave}")
      |> render(:show, chave: chave)
    end
  end

  operation(:show,
    summary: "Detalha uma chave",
    description: "Qualquer usuário logado.",
    parameters: ApiDoc.id(),
    responses:
      [ok: ApiDoc.json("Chave", Schemas.ChaveResposta)] ++
        ApiDoc.erros([:nao_autenticado, :nao_encontrado])
  )

  def show(conn, %{"id" => id}) do
    with {:ok, chave} <- Chaves.fetch_chave(id) do
      render(conn, :show, chave: chave)
    end
  end

  operation(:update,
    summary: "Edita uma chave",
    description: "Só admin. O status `emprestada` só muda pelo empréstimo e pela devolução.",
    parameters: ApiDoc.id(),
    request_body: ApiDoc.corpo(Schemas.ChaveEdicao),
    responses:
      [ok: ApiDoc.json("Chave atualizada", Schemas.ChaveResposta)] ++
        ApiDoc.erros_admin([:nao_encontrado, :conflito, :validacao])
  )

  def update(conn, %{"id" => id} = params) do
    with {:ok, chave} <- Chaves.fetch_chave(id),
         {:ok, %Chave{} = chave} <- Chaves.update_chave(chave, params) do
      render(conn, :show, chave: chave)
    end
  end

  operation(:delete,
    summary: "Exclui uma chave",
    description:
      "Só admin. Exclusão lógica (o histórico fica). Chave emprestada não pode ser excluída.",
    parameters: ApiDoc.id(),
    responses: [no_content: "Excluída"] ++ ApiDoc.erros_admin([:nao_encontrado, :conflito])
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, chave} <- Chaves.fetch_chave(id),
         {:ok, %Chave{}} <- Chaves.delete_chave(chave) do
      send_resp(conn, :no_content, "")
    end
  end
end
