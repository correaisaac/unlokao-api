defmodule UnlokaoWeb.UsuarioJSON do
  alias Unlokao.Usuarios.Usuario

  def index(%{usuarios: usuarios}) do
    %{data: for(usuario <- usuarios, do: data(usuario))}
  end

  def show(%{usuario: usuario}) do
    %{data: data(usuario)}
  end

  # A senha (e o hash dela) nunca sai da API.
  defp data(%Usuario{} = usuario) do
    %{
      id: usuario.id,
      nome: usuario.nome,
      email: usuario.email,
      matricula: usuario.matricula,
      telefone: usuario.telefone,
      perfil: usuario.perfil,
      inserted_at: usuario.inserted_at,
      updated_at: usuario.updated_at
    }
  end
end
