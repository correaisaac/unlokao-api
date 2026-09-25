defmodule Unlokao.AutenticacaoTest do
  use Unlokao.DataCase

  import Swoosh.TestAssertions
  import Unlokao.UsuariosFixtures

  alias Unlokao.{Autenticacao, Usuarios}
  alias Unlokao.Autenticacao.Token

  @senha "senha-segura-123"

  defp token_do_email do
    assert_email_sent(fn email -> send(self(), {:corpo, email.text_body}) end)
    assert_received {:corpo, corpo}
    [_, token] = Regex.run(~r/token=([\w-]+)/, corpo)
    token
  end

  defp envelhecer(token, contexto, horas) do
    {:ok, query} = Token.por_token(token, contexto)
    quando = DateTime.utc_now(:second) |> DateTime.add(-horas, :hour)
    Repo.update_all(query, set: [inserted_at: quando])
  end

  describe "autenticar/2 (#11)" do
    test "aceita e-mail (sem diferenciar maiúsculas) e senha corretos" do
      usuario = usuario_fixture(email: "maria@universidade.edu.br")
      assert {:ok, autenticado} = Autenticacao.autenticar(" Maria@Universidade.EDU.br ", @senha)
      assert autenticado.id == usuario.id
    end

    test "recusa senha errada, e-mail inexistente e usuário desativado com o mesmo erro" do
      usuario = usuario_fixture()

      assert {:error, :credenciais_invalidas} =
               Autenticacao.autenticar(usuario.email, "errada-123")

      assert {:error, :credenciais_invalidas} = Autenticacao.autenticar("ninguem@x.com", @senha)
      assert {:error, :credenciais_invalidas} = Autenticacao.autenticar(nil, nil)

      {:ok, _} = Usuarios.delete_usuario(usuario, usuario_fixture(perfil: :admin))
      assert {:error, :credenciais_invalidas} = Autenticacao.autenticar(usuario.email, @senha)
    end
  end

  describe "sessão (#11, #12)" do
    test "o token identifica o usuário até o logout" do
      usuario = usuario_fixture()
      token = Autenticacao.criar_token_de_sessao(usuario)

      assert Autenticacao.buscar_usuario_por_token_de_sessao(token).id == usuario.id
      assert :ok = Autenticacao.revogar_token_de_sessao(token)
      assert Autenticacao.buscar_usuario_por_token_de_sessao(token) == nil
    end

    test "o token não vale depois de 7 dias" do
      token = Autenticacao.criar_token_de_sessao(usuario_fixture())
      envelhecer(token, "sessao", 7 * 24 + 1)
      assert Autenticacao.buscar_usuario_por_token_de_sessao(token) == nil
    end

    test "o token não vale para usuário desativado" do
      usuario = usuario_fixture()
      token = Autenticacao.criar_token_de_sessao(usuario)
      {:ok, _} = Usuarios.delete_usuario(usuario, usuario_fixture(perfil: :admin))
      assert Autenticacao.buscar_usuario_por_token_de_sessao(token) == nil
    end

    test "texto que não é token não quebra" do
      assert Autenticacao.buscar_usuario_por_token_de_sessao("isso não é token!") == nil
      assert Autenticacao.buscar_usuario_por_token_de_sessao(nil) == nil
    end
  end

  describe "trocar_senha/4 (#14)" do
    test "troca a senha e encerra só as outras sessões" do
      usuario = usuario_fixture()
      atual = Autenticacao.criar_token_de_sessao(usuario)
      outra = Autenticacao.criar_token_de_sessao(usuario)

      assert {:ok, _} =
               Autenticacao.trocar_senha(usuario, @senha, %{senha: "nova-senha-123"}, atual)

      assert {:ok, _} = Autenticacao.autenticar(usuario.email, "nova-senha-123")
      assert Autenticacao.buscar_usuario_por_token_de_sessao(atual)
      refute Autenticacao.buscar_usuario_por_token_de_sessao(outra)
    end

    test "exige a senha atual correta e uma senha nova válida" do
      usuario = usuario_fixture()
      token = Autenticacao.criar_token_de_sessao(usuario)

      assert {:error, changeset} =
               Autenticacao.trocar_senha(usuario, "errada", %{senha: "curta"}, token)

      assert %{senha_atual: ["está incorreta"], senha: [_]} = errors_on(changeset)
      assert {:ok, _} = Autenticacao.autenticar(usuario.email, @senha)
    end
  end

  describe "redefinição de senha (#13)" do
    test "envia o link por e-mail e o token redefine a senha uma única vez" do
      usuario = usuario_fixture()
      sessao = Autenticacao.criar_token_de_sessao(usuario)

      assert :ok =
               Autenticacao.solicitar_redefinicao_de_senha(
                 usuario.email,
                 &"http://front/redefinir?token=#{&1}"
               )

      token = token_do_email()

      assert {:ok, _} = Autenticacao.redefinir_senha(token, %{senha: "nova-senha-123"})
      assert {:ok, _} = Autenticacao.autenticar(usuario.email, "nova-senha-123")
      refute Autenticacao.buscar_usuario_por_token_de_sessao(sessao), "encerra as sessões"

      assert {:error, :token_invalido} =
               Autenticacao.redefinir_senha(token, %{senha: "outra-senha-123"})
    end

    test "não envia nada para e-mail desconhecido, mas responde igual" do
      assert :ok =
               Autenticacao.solicitar_redefinicao_de_senha("ninguem@x.com", &"url?token=#{&1}")

      assert :ok = Autenticacao.solicitar_redefinicao_de_senha(nil, &"url?token=#{&1}")
      assert_no_email_sent()
    end

    test "token expira em 1 hora" do
      usuario = usuario_fixture()
      Autenticacao.solicitar_redefinicao_de_senha(usuario.email, &"url?token=#{&1}")
      token = token_do_email()
      envelhecer(token, "redefinir_senha", 2)

      assert {:error, :token_invalido} =
               Autenticacao.redefinir_senha(token, %{senha: "nova-senha-123"})
    end

    test "token deixa de valer se o e-mail do usuário mudou" do
      usuario = usuario_fixture()
      Autenticacao.solicitar_redefinicao_de_senha(usuario.email, &"url?token=#{&1}")
      token = token_do_email()
      {:ok, _} = Usuarios.update_usuario(usuario, %{email: "novo@universidade.edu.br"})

      assert {:error, :token_invalido} =
               Autenticacao.redefinir_senha(token, %{senha: "nova-senha-123"})
    end

    test "senha nova inválida não consome o token" do
      usuario = usuario_fixture()
      Autenticacao.solicitar_redefinicao_de_senha(usuario.email, &"url?token=#{&1}")
      token = token_do_email()

      assert {:error, %Ecto.Changeset{}} = Autenticacao.redefinir_senha(token, %{senha: "curta"})
      assert {:ok, _} = Autenticacao.redefinir_senha(token, %{senha: "nova-senha-123"})
    end

    test "token inválido" do
      assert {:error, :token_invalido} =
               Autenticacao.redefinir_senha("abc", %{senha: "nova-senha-123"})

      assert {:error, :token_invalido} =
               Autenticacao.redefinir_senha(nil, %{senha: "nova-senha-123"})
    end
  end
end
