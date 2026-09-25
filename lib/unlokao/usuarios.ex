defmodule Unlokao.Usuarios do
  @moduledoc """
  Cadastro das pessoas que pegam chaves emprestadas e das que operam o sistema.
  """

  import Ecto.Query, warn: false
  alias Unlokao.Repo

  alias Unlokao.Paginacao
  alias Unlokao.Usuarios.Usuario

  @doc """
  Lista os usuários ativos, ordenados pelo nome, com paginação.

  Filtros: `perfil` e `busca` (procura no nome, e-mail e matrícula).
  """
  def list_usuarios(params \\ %{}) do
    filtros = %{perfil: Paginacao.enum(Ecto.Enum.values(Usuario, :perfil)), busca: :string}

    with {:ok, params} <- Paginacao.validar(params, filtros) do
      query =
        Enum.reduce(params, where(Usuario, ativo: true), fn
          {:perfil, perfil}, query ->
            where(query, perfil: ^perfil)

          {:busca, busca}, query ->
            padrao = Paginacao.contem(busca)

            where(
              query,
              [u],
              ilike(u.nome, ^padrao) or ilike(u.email, ^padrao) or ilike(u.matricula, ^padrao)
            )

          _, query ->
            query
        end)

      {:ok, query |> order_by([:nome, :id]) |> Paginacao.paginar(params)}
    end
  end

  @doc """
  Busca um usuário ativo.

  Retorna `{:error, :not_found}` se o id for inválido, não existir ou o usuário tiver sido desativado.
  """
  def fetch_usuario(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Usuario{} = usuario <- Repo.get_by(Usuario, id: uuid, ativo: true) do
      {:ok, usuario}
    else
      _ -> {:error, :not_found}
    end
  end

  def create_usuario(attrs) do
    %Usuario{}
    |> Usuario.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_usuario(%Usuario{} = usuario, attrs) do
    usuario
    |> Usuario.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Desativa um usuário. `ator` é quem está fazendo a exclusão: ninguém exclui a si mesmo.
  As sessões do usuário deixam de valer porque só usuários ativos são autenticados.

  TODO (épico de empréstimo): bloquear quando o usuário tiver chave não devolvida.
  """
  def delete_usuario(%Usuario{id: id}, %Usuario{id: id}),
    do: {:error, {:unprocessable, "você não pode excluir o próprio usuário"}}

  def delete_usuario(%Usuario{} = usuario, %Usuario{} = _ator) do
    usuario
    |> Usuario.delete_changeset()
    |> Repo.update()
  end
end
