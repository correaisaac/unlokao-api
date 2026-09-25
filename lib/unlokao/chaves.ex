defmodule Unlokao.Chaves do
  @moduledoc """
  Cadastro das chaves físicas que dão acesso aos espaços da universidade.
  """

  import Ecto.Query, warn: false
  alias Unlokao.Repo

  alias Unlokao.Chaves.Chave

  @doc "Lista as chaves ativas, ordenadas pelo código."
  def list_chaves do
    Chave
    |> where(ativo: true)
    |> order_by(:codigo)
    |> Repo.all()
  end

  @doc """
  Busca uma chave ativa.

  Retorna `{:error, :not_found}` se o id for inválido, não existir ou a chave tiver sido excluída.
  """
  def fetch_chave(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Chave{} = chave <- Repo.get_by(Chave, id: uuid, ativo: true) do
      {:ok, chave}
    else
      _ -> {:error, :not_found}
    end
  end

  def create_chave(attrs) do
    %Chave{}
    |> Chave.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_chave(%Chave{} = chave, attrs) do
    chave
    |> Chave.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Exclui (logicamente) uma chave. Chave emprestada precisa ser devolvida antes.
  """
  def delete_chave(%Chave{status: :emprestada}),
    do:
      {:error,
       {:conflict, "a chave está emprestada e precisa ser devolvida antes de ser excluída"}}

  def delete_chave(%Chave{} = chave) do
    chave
    |> Chave.delete_changeset()
    |> Repo.update()
  end
end
