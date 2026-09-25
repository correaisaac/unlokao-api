defmodule Unlokao.UsuariosTest do
  use Unlokao.DataCase

  alias Unlokao.Usuarios
  alias Unlokao.Usuarios.Usuario

  import Unlokao.UsuariosFixtures

  @valido %{
    nome: "Maria Silva",
    email: "Maria@Universidade.edu.br",
    matricula: "20231234",
    perfil: "aluno",
    senha: "senha-segura-123"
  }

  describe "create_usuario/1 (#6)" do
    test "cria o usuário, normaliza o e-mail e guarda só o hash da senha" do
      assert {:ok, %Usuario{} = usuario} = Usuarios.create_usuario(@valido)
      assert usuario.email == "maria@universidade.edu.br"
      assert usuario.senha == nil
      assert Pbkdf2.verify_pass("senha-segura-123", usuario.senha_hash)
    end

    test "exige nome, e-mail, matrícula, perfil e senha" do
      assert {:error, changeset} = Usuarios.create_usuario(%{})

      assert %{nome: [_], email: [_], matricula: [_], perfil: [_], senha: [_]} =
               errors_on(changeset)
    end

    test "valida e-mail, perfil e tamanho da senha" do
      attrs = %{@valido | email: "invalido", perfil: "reitor", senha: "curta"}
      assert {:error, changeset} = Usuarios.create_usuario(attrs)

      assert %{email: ["não é um e-mail válido"], perfil: ["is invalid"], senha: [_]} =
               errors_on(changeset)
    end

    test "não aceita e-mail nem matrícula duplicados" do
      usuario_fixture(email: "maria@universidade.edu.br", matricula: "20231234")
      assert {:error, changeset} = Usuarios.create_usuario(@valido)
      assert %{email: ["já está em uso por outro usuário"]} = errors_on(changeset)

      assert {:error, changeset} =
               Usuarios.create_usuario(%{@valido | email: "outra@universidade.edu.br"})

      assert %{matricula: ["já está em uso por outro usuário"]} = errors_on(changeset)
    end
  end

  describe "list_usuarios/1 (#26)" do
    test "filtra por perfil e busca em nome, e-mail e matrícula" do
      maria = usuario_fixture(nome: "Maria", matricula: "111")
      joao = usuario_fixture(nome: "João", perfil: :professor, email: "joao@uni.edu.br")

      assert {:ok, %{itens: [^joao]}} = Usuarios.list_usuarios(%{"perfil" => "professor"})
      assert {:ok, %{itens: [^maria]}} = Usuarios.list_usuarios(%{"busca" => "MAR"})
      assert {:ok, %{itens: [^joao]}} = Usuarios.list_usuarios(%{"busca" => "joao@"})
      assert {:ok, %{itens: [^maria]}} = Usuarios.list_usuarios(%{"busca" => "111"})
    end
  end

  describe "update_usuario/2 (#7)" do
    test "atualiza os dados" do
      usuario = usuario_fixture()

      assert {:ok, usuario} =
               Usuarios.update_usuario(usuario, %{telefone: "83 99999-0000", perfil: "professor"})

      assert usuario.telefone == "83 99999-0000"
      assert usuario.perfil == :professor
    end

    test "não troca a senha" do
      usuario = usuario_fixture()
      assert {:ok, atualizado} = Usuarios.update_usuario(usuario, %{senha: "outra-senha-123"})
      assert atualizado.senha_hash == usuario.senha_hash
    end
  end

  describe "delete_usuario/2 (#8)" do
    test "desativa: some da listagem e da busca, mas continua no banco" do
      admin = usuario_fixture(perfil: :admin)
      usuario = usuario_fixture()
      assert {:ok, %Usuario{ativo: false}} = Usuarios.delete_usuario(usuario, admin)
      assert {:ok, %{itens: [^admin]}} = Usuarios.list_usuarios()
      assert Usuarios.fetch_usuario(usuario.id) == {:error, :not_found}
      assert Repo.get(Usuario, usuario.id)
    end

    test "ninguém exclui a si mesmo" do
      admin = usuario_fixture(perfil: :admin)
      assert {:error, {:unprocessable, _}} = Usuarios.delete_usuario(admin, admin)
    end
  end
end
