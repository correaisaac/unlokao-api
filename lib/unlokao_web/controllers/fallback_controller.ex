defmodule UnlokaoWeb.FallbackController do
  @moduledoc """
  Traduz os erros dos controllers em respostas HTTP:

    * campo duplicado (código, e-mail, matrícula) -> 409
    * outros erros de validação                   -> 422
    * regra de negócio em conflito                -> 409
  """
  use UnlokaoWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(if duplicado?(changeset), do: :conflict, else: :unprocessable_entity)
    |> put_view(json: UnlokaoWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, {:conflict, mensagem}}) do
    conn
    |> put_status(:conflict)
    |> json(%{errors: %{detail: mensagem}})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: UnlokaoWeb.ErrorJSON)
    |> render(:"404")
  end

  defp duplicado?(changeset) do
    Enum.any?(changeset.errors, fn {_campo, {_msg, opts}} -> opts[:constraint] == :unique end)
  end
end
