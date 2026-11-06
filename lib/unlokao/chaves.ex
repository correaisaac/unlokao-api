defmodule Unlokao.Chaves do
  @moduledoc """
  Cadastro das chaves físicas que dão acesso aos espaços da universidade.
  """

  import Ecto.Query, warn: false
  alias Unlokao.Repo

  alias Unlokao.Chaves.{Autorizacao, Chave}
  alias Unlokao.Paginacao
  alias Unlokao.Usuarios.Usuario

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

  @doc """
  Lista de quem pode retirar a chave, em ordem de nome, com paginação.

  Filtro: `usuario_id`. Quem foi desativado não aparece.
  """
  def list_autorizacoes(%Chave{id: chave_id}, params \\ %{}) do
    with {:ok, params} <- Paginacao.validar(params, %{usuario_id: Ecto.UUID}) do
      query =
        from a in Autorizacao,
          join: u in assoc(a, :usuario),
          where: a.chave_id == ^chave_id and u.ativo,
          order_by: [u.nome, a.id],
          preload: [:usuario, :autorizado_por]

      query =
        case params do
          %{usuario_id: usuario_id} -> where(query, usuario_id: ^usuario_id)
          _ -> query
        end

      {:ok, Paginacao.paginar(query, params)}
    end
  end

  @doc "Coloca uma pessoa já cadastrada na lista da chave. `ator` fica como quem autorizou."
  def autorizar(%Chave{id: chave_id}, attrs, %Usuario{id: ator_id}) do
    changeset =
      Autorizacao.changeset(%Autorizacao{chave_id: chave_id, autorizado_por_id: ator_id}, attrs)

    with {:ok, dados} <- Ecto.Changeset.apply_action(changeset, :insert),
         :ok <- verificar_usuario(dados.usuario_id, changeset),
         {:ok, autorizacao} <- Repo.insert(changeset) do
      {:ok, Repo.preload(autorizacao, [:usuario, :autorizado_por])}
    end
  end

  @doc "Tira uma pessoa da lista. Retorna `{:error, :not_found}` se a autorização não for desta chave."
  def remover_autorizacao(%Chave{id: chave_id}, id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Autorizacao{} = autorizacao <- Repo.get_by(Autorizacao, id: uuid, chave_id: chave_id) do
      Repo.delete(autorizacao)
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "Chave livre: qualquer pessoa. Chave restrita: só quem tem autorização ainda válida."
  def pode_retirar?(chave_id, usuario_id) do
    hoje = Date.utc_today()

    not Repo.exists?(from c in Chave, where: c.id == ^chave_id and c.restrita) or
      Repo.exists?(
        from a in Autorizacao,
          where:
            a.chave_id == ^chave_id and a.usuario_id == ^usuario_id and
              (is_nil(a.valida_ate) or a.valida_ate >= ^hoje)
      )
  end

  defp verificar_usuario(usuario_id, changeset) do
    if Repo.exists?(from u in Usuario, where: u.id == ^usuario_id and u.ativo),
      do: :ok,
      else: {:error, Ecto.Changeset.add_error(changeset, :usuario_id, "não encontrado")}
  end
end
