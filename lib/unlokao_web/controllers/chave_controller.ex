defmodule UnlokaoWeb.ChaveController do
  use UnlokaoWeb, :controller

  alias Unlokao.Chaves
  alias Unlokao.Chaves.Chave

  action_fallback UnlokaoWeb.FallbackController

  def index(conn, params) do
    with {:ok, pagina} <- Chaves.list_chaves(params) do
      render(conn, :index, pagina: pagina)
    end
  end

  def create(conn, params) do
    with {:ok, %Chave{} = chave} <- Chaves.create_chave(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/chaves/#{chave}")
      |> render(:show, chave: chave)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, chave} <- Chaves.fetch_chave(id) do
      render(conn, :show, chave: chave)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, chave} <- Chaves.fetch_chave(id),
         {:ok, %Chave{} = chave} <- Chaves.update_chave(chave, params) do
      render(conn, :show, chave: chave)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, chave} <- Chaves.fetch_chave(id),
         {:ok, %Chave{}} <- Chaves.delete_chave(chave) do
      send_resp(conn, :no_content, "")
    end
  end
end
