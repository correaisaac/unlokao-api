defmodule UnlokaoWeb.UsuarioController do
  use UnlokaoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias Unlokao.Usuarios
  alias Unlokao.Usuarios.Usuario
  alias UnlokaoWeb.{ApiDoc, Schemas}

  action_fallback UnlokaoWeb.FallbackController

  tags(["Usuários"])

  operation(:index,
    summary: "Lista os usuários ativos",
    description: "Só admin.",
    parameters:
      ApiDoc.paginacao(
        perfil: ApiDoc.filtro("Perfil", %Schema{type: :string, enum: Schemas.Base.perfis()}),
        busca: ApiDoc.filtro("Procura no nome, e-mail e matrícula", %Schema{type: :string})
      ),
    responses:
      [ok: ApiDoc.json("Usuários", Schemas.UsuarioLista)] ++ ApiDoc.erros_admin([:validacao])
  )

  def index(conn, params) do
    with {:ok, pagina} <- Usuarios.list_usuarios(params) do
      render(conn, :index, pagina: pagina)
    end
  end

  operation(:create,
    summary: "Cadastra um usuário",
    description: "Só admin.",
    request_body: ApiDoc.corpo(Schemas.UsuarioEntrada),
    responses:
      [created: ApiDoc.json("Usuário criado", Schemas.UsuarioResposta)] ++
        ApiDoc.erros_admin([:conflito, :validacao])
  )

  def create(conn, params) do
    with {:ok, %Usuario{} = usuario} <- Usuarios.create_usuario(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/usuarios/#{usuario}")
      |> render(:show, usuario: usuario)
    end
  end

  operation(:show,
    summary: "Detalha um usuário",
    description: "Só admin.",
    parameters: ApiDoc.id(),
    responses:
      [ok: ApiDoc.json("Usuário", Schemas.UsuarioResposta)] ++
        ApiDoc.erros_admin([:nao_encontrado])
  )

  def show(conn, %{"id" => id}) do
    with {:ok, usuario} <- Usuarios.fetch_usuario(id) do
      render(conn, :show, usuario: usuario)
    end
  end

  operation(:update,
    summary: "Edita um usuário",
    description: "Só admin. A senha não muda por aqui.",
    parameters: ApiDoc.id(),
    request_body: ApiDoc.corpo(Schemas.UsuarioEdicao),
    responses:
      [ok: ApiDoc.json("Usuário atualizado", Schemas.UsuarioResposta)] ++
        ApiDoc.erros_admin([:nao_encontrado, :conflito, :validacao])
  )

  def update(conn, %{"id" => id} = params) do
    with {:ok, usuario} <- Usuarios.fetch_usuario(id),
         {:ok, %Usuario{} = usuario} <- Usuarios.update_usuario(usuario, params) do
      render(conn, :show, usuario: usuario)
    end
  end

  operation(:delete,
    summary: "Desativa um usuário",
    description: """
    Só admin. Exclusão lógica (o histórico fica). Não é possível excluir o
    próprio usuário (422) nem quem está com chave emprestada (409).
    """,
    parameters: ApiDoc.id(),
    responses:
      [no_content: "Desativado"] ++ ApiDoc.erros_admin([:nao_encontrado, :conflito, :validacao])
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, usuario} <- Usuarios.fetch_usuario(id),
         {:ok, %Usuario{}} <- Usuarios.delete_usuario(usuario, conn.assigns.usuario_atual) do
      send_resp(conn, :no_content, "")
    end
  end
end
