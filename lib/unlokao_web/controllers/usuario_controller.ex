defmodule UnlokaoWeb.UsuarioController do
  use UnlokaoWeb, :controller

  alias Unlokao.Usuarios
  alias Unlokao.Usuarios.Usuario

  action_fallback UnlokaoWeb.FallbackController

  def index(conn, _params) do
    usuarios = Usuarios.list_usuarios()
    render(conn, :index, usuarios: usuarios)
  end

  def create(conn, params) do
    with {:ok, %Usuario{} = usuario} <- Usuarios.create_usuario(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/usuarios/#{usuario}")
      |> render(:show, usuario: usuario)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, usuario} <- Usuarios.fetch_usuario(id) do
      render(conn, :show, usuario: usuario)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, usuario} <- Usuarios.fetch_usuario(id),
         {:ok, %Usuario{} = usuario} <- Usuarios.update_usuario(usuario, params) do
      render(conn, :show, usuario: usuario)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, usuario} <- Usuarios.fetch_usuario(id),
         {:ok, %Usuario{}} <- Usuarios.delete_usuario(usuario, conn.assigns.usuario_atual) do
      send_resp(conn, :no_content, "")
    end
  end
end
