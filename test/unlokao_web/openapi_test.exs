defmodule UnlokaoWeb.OpenApiTest do
  @moduledoc """
  Garante que a documentação OpenAPI (#25) cobre todas as rotas e que as
  respostas reais batem com os schemas documentados.
  """
  use UnlokaoWeb.ConnCase

  import Swoosh.TestAssertions
  import Unlokao.ChavesFixtures
  import Unlokao.EmprestimosFixtures
  import Unlokao.UsuariosFixtures

  @senha "senha-segura-123"

  describe "especificação" do
    test "toda rota da API está documentada" do
      spec = UnlokaoWeb.ApiSpec.spec()

      nao_documentadas =
        for rota <- Phoenix.Router.routes(UnlokaoWeb.Router),
            rota.path not in ["/api/openapi", "/api/docs"],
            caminho = String.replace(rota.path, ~r/:(\w+)/, "{\\1}"),
            is_nil(get_in(spec.paths, [caminho, Access.key(rota.verb)])),
            do: "#{rota.verb |> to_string() |> String.upcase()} #{rota.path}"

      assert nao_documentadas == []
    end

    test "GET /api/openapi devolve a especificação em JSON", %{conn: conn} do
      spec = conn |> get(~p"/api/openapi") |> json_response(200)

      assert spec["info"]["title"] == "Unlokao API"
      assert spec["paths"]["/api/emprestimos"]["post"]
      assert spec["components"]["securitySchemes"]["token"]["scheme"] == "bearer"
      assert spec["paths"]["/api/login"]["post"]["security"] == []
    end

    test "GET /api/docs abre o Swagger UI", %{conn: conn} do
      assert conn |> get(~p"/api/docs") |> html_response(200) =~ "swagger"
    end
  end

  describe "as respostas batem com a documentação" do
    setup %{conn: conn} do
      admin = usuario_fixture(perfil: :admin)
      %{admin: admin, conn: autenticar(conn, admin)}
    end

    test "autenticação e minha conta", %{admin: admin} do
      usuario = usuario_fixture()
      publico = build_conn()

      publico |> post(~p"/api/login", email: usuario.email, senha: @senha) |> assert_documentado()

      publico
      |> post(~p"/api/login", email: usuario.email, senha: "errada")
      |> assert_documentado()

      publico |> get(~p"/api/me") |> assert_documentado()

      logado = autenticar(build_conn(), usuario)
      logado |> get(~p"/api/me") |> assert_documentado()
      logado |> get(~p"/api/me/emprestimos") |> assert_documentado()
      logado |> put(~p"/api/me/senha", senha_atual: "errada", senha: "x") |> assert_documentado()

      logado
      |> put(~p"/api/me/senha", senha_atual: @senha, senha: "nova-senha-123")
      |> assert_documentado()

      logado |> get(~p"/api/usuarios") |> assert_documentado()
      logado |> post(~p"/api/logout") |> assert_documentado()

      publico |> post(~p"/api/senha/esqueci", email: admin.email) |> assert_documentado()
      assert_email_sent()

      publico
      |> post(~p"/api/senha/redefinir", token: "x", senha: "nova-senha-123")
      |> assert_documentado()
    end

    test "chaves", %{conn: conn} do
      chave = chave_fixture()

      conn |> get(~p"/api/chaves?busca=lab") |> assert_documentado()
      conn |> get(~p"/api/chaves?status=sumida") |> assert_documentado()
      conn |> get(~p"/api/chaves/#{chave}") |> assert_documentado()
      conn |> get(~p"/api/chaves/#{Ecto.UUID.generate()}") |> assert_documentado()
      conn |> post(~p"/api/chaves", codigo: "NOVA-1", espaco: "Sala 1") |> assert_documentado()
      conn |> post(~p"/api/chaves", codigo: "NOVA-1", espaco: "Sala 1") |> assert_documentado()
      conn |> post(~p"/api/chaves", %{}) |> assert_documentado()
      conn |> patch(~p"/api/chaves/#{chave}", bloco: "C") |> assert_documentado()
      conn |> delete(~p"/api/chaves/#{chave}") |> assert_documentado()
    end

    test "usuários", %{conn: conn, admin: admin} do
      usuario = usuario_fixture()

      conn |> get(~p"/api/usuarios?perfil=aluno") |> assert_documentado()
      conn |> get(~p"/api/usuarios/#{usuario}") |> assert_documentado()

      conn
      |> post(~p"/api/usuarios",
        nome: "Ana",
        email: "ana@uni.edu.br",
        matricula: "555",
        perfil: "aluno",
        senha: @senha
      )
      |> assert_documentado()

      conn |> post(~p"/api/usuarios", %{}) |> assert_documentado()

      conn
      |> patch(~p"/api/usuarios/#{usuario}", telefone: "83 1234-5678")
      |> assert_documentado()

      conn |> delete(~p"/api/usuarios/#{admin}") |> assert_documentado()
      conn |> delete(~p"/api/usuarios/#{usuario}") |> assert_documentado()
    end

    test "empréstimos", %{conn: conn, admin: admin} do
      chave = chave_fixture()
      usuario = usuario_fixture()
      atrasado = emprestimo_fixture(admin: admin) |> atrasar()

      conn = post(conn, ~p"/api/emprestimos", chave_id: chave.id, usuario_id: usuario.id)
      %{"id" => id} = assert_documentado(conn) |> json_response(201) |> Map.fetch!("data")

      conn = recycle(conn)

      conn
      |> post(~p"/api/emprestimos", chave_id: chave.id, usuario_id: usuario.id)
      |> assert_documentado()

      conn |> post(~p"/api/emprestimos", chave_id: "x") |> assert_documentado()
      conn |> get(~p"/api/emprestimos?situacao=atrasado") |> assert_documentado()
      conn |> get(~p"/api/emprestimos/#{atrasado}") |> assert_documentado()
      conn |> post(~p"/api/emprestimos/#{id}/devolucao") |> assert_documentado()
      conn |> post(~p"/api/emprestimos/#{id}/devolucao") |> assert_documentado()
      conn |> get(~p"/api/emprestimos/#{Ecto.UUID.generate()}") |> assert_documentado()
    end
  end
end
