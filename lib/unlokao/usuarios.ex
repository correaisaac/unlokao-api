defmodule Unlokao.Usuarios do
  @moduledoc """
  Cadastro das pessoas que pegam chaves emprestadas e das que operam o sistema.
  """

  import Ecto.Query, warn: false
  alias Unlokao.Repo

  alias Unlokao.Usuarios.Usuario

  @doc "Lista os usuários ativos, ordenados pelo nome."
  def list_usuarios do
    Usuario
    |> where(ativo: true)
    |> order_by(:nome)
    |> Repo.all()
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
  Desativa um usuário.

  TODO (épico de empréstimo): bloquear quando o usuário tiver chave não devolvida.
  """
  def delete_usuario(%Usuario{} = usuario) do
    usuario
    |> Usuario.delete_changeset()
    |> Repo.update()
  end
end
