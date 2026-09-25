defmodule UnlokaoWeb.SessaoJSON do
  alias UnlokaoWeb.UsuarioJSON

  def create(%{token: token, usuario: usuario}) do
    %{data: %{token: token, usuario: UsuarioJSON.data(usuario)}}
  end
end
