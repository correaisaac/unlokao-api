defmodule UnlokaoWeb.AutenticacaoControllerTest do
  use UnlokaoWeb.ConnCase

  import Swoosh.TestAssertions
  import Unlokao.ChavesFixtures
  import Unlokao.UsuariosFixtures

  @senha "senha-segura-123"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/login (#11)" do
    test "200 com token e dados do usuário, sem senha", %{conn: conn} do
      usuario = usuario_fixture()
      conn = post(conn, ~p"/api/login", email: usuario.email, senha: @senha)

      assert %{"token" => token, "usuario" => dados} = json_response(conn, 200)["data"]
      assert is_binary(token)
      assert dados["id"] == usuario.id
      refute Map.has_key?(dados, "senha_hash")
    end

    test "401 com a mesma mensagem para senha errada e e-mail inexistente", %{conn: conn} do
      usuario = usuario_fixture()

      errada =
        conn
        |> post(~p"/api/login", email: usuario.email, senha: "errada-123")
        |> json_response(401)

      inexistente =
        conn |> post(~p"/api/login", email: "ninguem@x.com", senha: @senha) |> json_response(401)

      assert errada == inexistente
      assert json_response(post(conn, ~p"/api/login", %{}), 401)
    end
  end

  test "POST /api/logout invalida o token (#11)", %{conn: conn} do
    conn = autenticar(conn, usuario_fixture())

    assert response(post(conn, ~p"/api/logout"), 204)
    assert json_response(get(conn, ~p"/api/me"), 401)
  end

  describe "proteção das rotas (#12)" do
    test "401 sem token ou com token inválido", %{conn: conn} do
      assert %{"detail" => _} = json_response(get(conn, ~p"/api/chaves"), 401)["errors"]

      conn = put_req_header(conn, "authorization", "Bearer token-falso")
      assert json_response(get(conn, ~p"/api/me"), 401)
    end

    test "rotas públicas não exigem token", %{conn: conn} do
      assert response(post(conn, ~p"/api/senha/esqueci", email: "x@x.com"), 204)
    end

    test "quem não é admin consulta chaves, mas não gerencia nada", %{conn: conn} do
      chave = chave_fixture()
      conn = autenticar(conn, usuario_fixture(perfil: :professor))

      assert json_response(get(conn, ~p"/api/chaves"), 200)
      assert json_response(get(conn, ~p"/api/chaves/#{chave}"), 200)

      assert json_response(post(conn, ~p"/api/chaves", codigo: "X", espaco: "Y"), 403)
      assert json_response(patch(conn, ~p"/api/chaves/#{chave}", espaco: "Y"), 403)
      assert json_response(delete(conn, ~p"/api/chaves/#{chave}"), 403)
      assert json_response(get(conn, ~p"/api/usuarios"), 403)
    end

    test "GET /api/me retorna o usuário logado", %{conn: conn} do
      usuario = usuario_fixture()
      conn = conn |> autenticar(usuario) |> get(~p"/api/me")
      assert json_response(conn, 200)["data"]["id"] == usuario.id
    end
  end

  describe "PUT /api/me/senha (#14)" do
    test "204 com a senha atual correta", %{conn: conn} do
      usuario = usuario_fixture()

      conn =
        conn
        |> autenticar(usuario)
        |> put(~p"/api/me/senha", senha_atual: @senha, senha: "nova-senha-123")

      assert response(conn, 204)

      assert json_response(
               post(build_conn(), ~p"/api/login", email: usuario.email, senha: "nova-senha-123"),
               200
             )
    end

    test "422 com a senha atual errada", %{conn: conn} do
      conn =
        conn
        |> autenticar(usuario_fixture())
        |> put(~p"/api/me/senha", senha_atual: "errada", senha: "nova-senha-123")

      assert %{"senha_atual" => ["está incorreta"]} = json_response(conn, 422)["errors"]
    end
  end

  describe "esqueci minha senha (#13)" do
    test "204 para e-mail cadastrado ou não; só o cadastrado recebe o link", %{conn: conn} do
      assert response(post(conn, ~p"/api/senha/esqueci", email: "ninguem@x.com"), 204)
      assert_no_email_sent()

      usuario = usuario_fixture()
      assert response(post(conn, ~p"/api/senha/esqueci", email: usuario.email), 204)

      assert_email_sent(fn email ->
        assert email.to == [{usuario.nome, usuario.email}]
        assert email.text_body =~ "http://localhost:5173/redefinir-senha?token="
      end)
    end

    test "POST /api/senha/redefinir troca a senha com o token do e-mail", %{conn: conn} do
      usuario = usuario_fixture()
      post(conn, ~p"/api/senha/esqueci", email: usuario.email)
      assert_email_sent(fn email -> send(self(), {:corpo, email.text_body}) end)
      assert_received {:corpo, corpo}
      [_, token] = Regex.run(~r/token=([\w-]+)/, corpo)

      assert response(
               post(conn, ~p"/api/senha/redefinir", token: token, senha: "nova-senha-123"),
               204
             )

      assert json_response(
               post(conn, ~p"/api/login", email: usuario.email, senha: "nova-senha-123"),
               200
             )

      conn = post(conn, ~p"/api/senha/redefinir", token: token, senha: "outra-senha-123")

      assert %{"detail" => "link de redefinição inválido ou expirado"} =
               json_response(conn, 422)["errors"]
    end
  end
end
