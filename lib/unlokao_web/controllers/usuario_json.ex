defmodule UnlokaoWeb.UsuarioJSON do
  alias Unlokao.Usuarios.Usuario

  def index(%{pagina: pagina}) do
    UnlokaoWeb.PaginacaoJSON.render(pagina, &data/1)
  end

  def show(%{usuario: usuario}) do
    %{data: data(usuario)}
  end

  @doc "A senha (e o hash dela) nunca sai da API."
  def data(%Usuario{} = usuario) do
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
