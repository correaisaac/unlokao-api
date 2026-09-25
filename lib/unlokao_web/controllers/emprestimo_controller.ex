defmodule UnlokaoWeb.EmprestimoController do
  use UnlokaoWeb, :controller

  alias Unlokao.Emprestimos

  action_fallback UnlokaoWeb.FallbackController

  def index(conn, params) do
    with {:ok, pagina} <- Emprestimos.list_emprestimos(params) do
      render(conn, :index, pagina: pagina)
    end
  end

  def meus(conn, params) do
    with {:ok, pagina} <-
           Emprestimos.list_emprestimos_do_usuario(conn.assigns.usuario_atual, params) do
      render(conn, :index, pagina: pagina)
    end
  end

  def create(conn, params) do
    with {:ok, emprestimo} <- Emprestimos.registrar_emprestimo(params, conn.assigns.usuario_atual) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/emprestimos/#{emprestimo}")
      |> render(:show, emprestimo: emprestimo)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, emprestimo} <- Emprestimos.fetch_emprestimo(id) do
      render(conn, :show, emprestimo: emprestimo)
    end
  end

  def devolver(conn, %{"id" => id}) do
    with {:ok, emprestimo} <- Emprestimos.fetch_emprestimo(id),
         {:ok, emprestimo} <-
           Emprestimos.registrar_devolucao(emprestimo, conn.assigns.usuario_atual) do
      render(conn, :show, emprestimo: emprestimo)
    end
  end
end
