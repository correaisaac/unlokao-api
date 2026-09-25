defmodule Unlokao.Chaves do
  @moduledoc """
  Cadastro das chaves físicas que dão acesso aos espaços da universidade.
  """

  import Ecto.Query, warn: false
  alias Unlokao.Repo

  alias Unlokao.Chaves.Chave
  alias Unlokao.Paginacao

  @doc """
  Lista as chaves ativas, ordenadas pelo código, com paginação.

  Filtros: `status`, `bloco` e `busca` (procura no código e no espaço).
  """
  def list_chaves(params \\ %{}) do
    filtros = %{
      status: Paginacao.enum(Ecto.Enum.values(Chave, :status)),
      bloco: :string,
      busca: :string
    }

    with {:ok, params} <- Paginacao.validar(params, filtros) do
      query =
        Enum.reduce(params, where(Chave, ativo: true), fn
          {:status, status}, query ->
            where(query, status: ^status)

          {:bloco, bloco}, query ->
            where(query, [c], ilike(c.bloco, ^bloco))

          {:busca, busca}, query ->
            where(
              query,
              [c],
              ilike(c.codigo, ^Paginacao.contem(busca)) or
                ilike(c.espaco, ^Paginacao.contem(busca))
            )

          _, query ->
            query
        end)

      {:ok, query |> order_by([:codigo, :id]) |> Paginacao.paginar(params)}
    end
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
