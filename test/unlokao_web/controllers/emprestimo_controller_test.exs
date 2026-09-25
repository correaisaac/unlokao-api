defmodule UnlokaoWeb.EmprestimoControllerTest do
  use UnlokaoWeb.ConnCase

  import Unlokao.ChavesFixtures
  import Unlokao.EmprestimosFixtures
  import Unlokao.UsuariosFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup :autenticar_admin

  describe "POST /api/emprestimos (#18)" do
    test "201 com o empréstimo e a chave emprestada", %{conn: conn, admin: admin} do
      chave = chave_fixture()
      usuario = usuario_fixture()
      conn = post(conn, ~p"/api/emprestimos", chave_id: chave.id, usuario_id: usuario.id)

      assert %{"id" => id, "chave" => %{"id" => chave_id}, "atrasado" => false} =
               data = json_response(conn, 201)["data"]

      assert chave_id == chave.id
      assert data["entregue_por"]["id"] == admin.id
      assert data["recebido_por"] == nil
      assert get_resp_header(conn, "location") == ["/api/emprestimos/#{id}"]

      assert %{"status" => "emprestada"} =
               json_response(get(conn, ~p"/api/chaves/#{chave}"), 200)["data"]
    end

    test "409 com chave já emprestada", %{conn: conn, admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)

      conn =
        post(conn, ~p"/api/emprestimos",
          chave_id: emprestimo.chave.id,
          usuario_id: usuario_fixture().id
        )

      assert %{"detail" => "a chave não está disponível"} = json_response(conn, 409)["errors"]
    end

    test "422 com dados inválidos", %{conn: conn} do
      conn = post(conn, ~p"/api/emprestimos", chave_id: "x")
      assert %{"chave_id" => _, "usuario_id" => _} = json_response(conn, 422)["errors"]
    end
  end

  describe "POST /api/emprestimos/:id/devolucao (#19)" do
    test "200 e a chave volta a ficar disponível", %{conn: conn, admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)
      resposta = conn |> post(~p"/api/emprestimos/#{emprestimo}/devolucao") |> json_response(200)

      assert resposta["data"]["devolvida_em"]
      assert resposta["data"]["recebido_por"]["id"] == admin.id

      assert %{"status" => "disponivel"} =
               json_response(get(conn, ~p"/api/chaves/#{emprestimo.chave.id}"), 200)["data"]
    end

    test "409 se já devolvido e 404 se não existir", %{conn: conn, admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)
      post(conn, ~p"/api/emprestimos/#{emprestimo}/devolucao")

      assert json_response(post(conn, ~p"/api/emprestimos/#{emprestimo}/devolucao"), 409)

      assert json_response(
               post(conn, ~p"/api/emprestimos/#{Ecto.UUID.generate()}/devolucao"),
               404
             )
    end
  end

  describe "consultas (#20)" do
    test "GET /api/emprestimos filtra atrasados", %{conn: conn, admin: admin} do
      atrasado = emprestimo_fixture(admin: admin) |> atrasar()
      _em_dia = emprestimo_fixture(admin: admin)

      resposta = conn |> get(~p"/api/emprestimos?situacao=atrasado") |> json_response(200)
      assert [%{"id" => id, "atrasado" => true}] = resposta["data"]
      assert id == atrasado.id
      assert resposta["meta"]["total"] == 1
    end

    test "GET /api/emprestimos/:id", %{conn: conn, admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)

      assert json_response(get(conn, ~p"/api/emprestimos/#{emprestimo}"), 200)["data"]["id"] ==
               emprestimo.id

      assert json_response(get(conn, ~p"/api/emprestimos/nao-existe"), 404)
    end

    test "GET /api/me/emprestimos mostra só os do usuário logado", %{admin: admin} do
      meu = emprestimo_fixture(admin: admin)
      _outro = emprestimo_fixture(admin: admin)

      conn = build_conn() |> autenticar(meu.usuario) |> get(~p"/api/me/emprestimos")
      assert [%{"id" => id}] = json_response(conn, 200)["data"]
      assert id == meu.id
    end
  end

  test "quem não é admin não registra nem lista empréstimos" do
    conn = autenticar(build_conn(), usuario_fixture())

    assert json_response(get(conn, ~p"/api/emprestimos"), 403)
    assert json_response(post(conn, ~p"/api/emprestimos", %{}), 403)
  end

  test "DELETE /api/usuarios/:id retorna 409 se o usuário está com chave (#21)", %{
    conn: conn,
    admin: admin
  } do
    emprestimo = emprestimo_fixture(admin: admin)
    assert json_response(delete(conn, ~p"/api/usuarios/#{emprestimo.usuario.id}"), 409)
  end
end
