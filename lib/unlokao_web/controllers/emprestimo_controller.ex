defmodule UnlokaoWeb.EmprestimoController do
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias Unlokao.Emprestimos
  alias UnlokaoWeb.{ApiDoc, Schemas}

  action_fallback UnlokaoWeb.FallbackController

  tags(["Empréstimos"])

  @filtros [
    situacao:
      ApiDoc.filtro(
        "`aberto` (não devolvido), `atrasado` (não devolvido e fora do prazo) ou `devolvido`",
        %Schema{type: :string, enum: ["aberto", "atrasado", "devolvido"]}
      ),
    chave_id: ApiDoc.filtro("Só empréstimos desta chave", %Schema{type: :string, format: :uuid})
  ]

  operation(:index,
    summary: "Lista os empréstimos",
    description: "Só admin. Do mais recente para o mais antigo.",
    parameters:
      ApiDoc.paginacao(
        @filtros ++
          [
            usuario_id:
              ApiDoc.filtro("Só empréstimos deste usuário", %Schema{type: :string, format: :uuid})
          ]
      ),
    responses:
      [ok: ApiDoc.json("Empréstimos", Schemas.EmprestimoLista)] ++
        ApiDoc.erros_admin([:validacao])
  )

  def index(conn, params) do
    with {:ok, pagina} <- Emprestimos.list_emprestimos(params) do
      render(conn, :index, pagina: pagina)
    end
  end

  operation(:meus,
    summary: "Meus empréstimos",
    description: "Empréstimos do usuário logado, do mais recente para o mais antigo.",
    tags: ["Minha conta"],
    parameters: ApiDoc.paginacao(@filtros),
    responses:
      [ok: ApiDoc.json("Empréstimos", Schemas.EmprestimoLista)] ++
        ApiDoc.erros([:nao_autenticado, :validacao])
  )

  def meus(conn, params) do
    with {:ok, pagina} <-
           Emprestimos.list_emprestimos_do_usuario(conn.assigns.usuario_atual, params) do
      render(conn, :index, pagina: pagina)
    end
  end

  operation(:create,
    summary: "Registra a retirada de uma chave",
    description: """
    Só admin. A chave precisa estar `disponivel` e passa para `emprestada`;
    o admin logado fica como quem entregou.
    """,
    request_body: ApiDoc.corpo(Schemas.EmprestimoEntrada),
    responses:
      [created: ApiDoc.json("Empréstimo registrado", Schemas.EmprestimoResposta)] ++
        ApiDoc.erros_admin([:conflito, :validacao])
  )

  def create(conn, params) do
    with {:ok, emprestimo} <- Emprestimos.registrar_emprestimo(params, conn.assigns.usuario_atual) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/emprestimos/#{emprestimo}")
      |> render(:show, emprestimo: emprestimo)
    end
  end

  operation(:show,
    summary: "Detalha um empréstimo",
    description: "Só admin.",
    parameters: ApiDoc.id(),
    responses:
      [ok: ApiDoc.json("Empréstimo", Schemas.EmprestimoResposta)] ++
        ApiDoc.erros_admin([:nao_encontrado])
  )

  def show(conn, %{"id" => id}) do
    with {:ok, emprestimo} <- Emprestimos.fetch_emprestimo(id) do
      render(conn, :show, emprestimo: emprestimo)
    end
  end

  operation(:devolver,
    summary: "Registra a devolução",
    description:
      "Só admin. A chave volta a ficar `disponivel`; o admin logado fica como quem recebeu.",
    parameters: ApiDoc.id("Id do empréstimo"),
    responses:
      [ok: ApiDoc.json("Empréstimo devolvido", Schemas.EmprestimoResposta)] ++
        ApiDoc.erros_admin([:nao_encontrado, :conflito])
  )

  def devolver(conn, %{"id" => id}) do
    with {:ok, emprestimo} <- Emprestimos.fetch_emprestimo(id),
         {:ok, emprestimo} <-
           Emprestimos.registrar_devolucao(emprestimo, conn.assigns.usuario_atual) do
      render(conn, :show, emprestimo: emprestimo)
    end
  end
end
