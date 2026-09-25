defmodule Unlokao.UsuariosFixtures do
  @moduledoc "Helpers para criar usuários nos testes."

  def unique_usuario_email, do: "usuario#{System.unique_integer([:positive])}@universidade.edu.br"
  def unique_usuario_matricula, do: "#{System.unique_integer([:positive])}"

  def usuario_fixture(attrs \\ %{}) do
    {:ok, usuario} =
      attrs
      |> Enum.into(%{
        nome: "Maria Silva",
        email: unique_usuario_email(),
        matricula: unique_usuario_matricula(),
        perfil: :aluno,
        senha: "senha-segura-123"
      })
      |> Unlokao.Usuarios.create_usuario()

    usuario
  end
end
