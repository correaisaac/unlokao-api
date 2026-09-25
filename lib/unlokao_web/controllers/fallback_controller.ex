defmodule UnlokaoWeb.FallbackController do
  @moduledoc """
  Traduz os erros dos controllers em respostas HTTP:

    * campo duplicado (código, e-mail, matrícula) -> 409
    * outros erros de validação                   -> 422
    * regra de negócio em conflito                -> 409
    * regra de negócio que impede a ação          -> 422
    * e-mail ou senha errados no login            -> 401
    * link de redefinição de senha inválido       -> 422
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

  def call(conn, {:error, {:unprocessable, mensagem}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: mensagem}})
  end

  def call(conn, {:error, :credenciais_invalidas}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "e-mail ou senha inválidos"}})
  end

  def call(conn, {:error, :token_invalido}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "link de redefinição inválido ou expirado"}})
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
