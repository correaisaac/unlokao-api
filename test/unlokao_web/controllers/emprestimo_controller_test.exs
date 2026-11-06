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

  describe "POST /api/emprestimos/lote" do
    test "201 com um empréstimo por chave, todos para a mesma pessoa", %{conn: conn, admin: admin} do
      [a, b] = [chave_fixture(), chave_fixture()]
      usuario = usuario_fixture()

      resposta =
        post(conn, ~p"/api/emprestimos/lote",
          chave_ids: [a.id, b.id, a.id],
          usuario_id: usuario.id,
          observacao: "aula de reposição"
        )

      assert [primeiro, segundo] = json_response(resposta, 201)["data"]

      assert Enum.sort([primeiro["chave"]["id"], segundo["chave"]["id"]]) ==
               Enum.sort([a.id, b.id])

      assert primeiro["usuario"]["id"] == usuario.id
      assert primeiro["entregue_por"]["id"] == admin.id
      assert primeiro["prazo"] == segundo["prazo"]
      assert segundo["observacao"] == "aula de reposição"

      for chave <- [a, b] do
        assert %{"status" => "emprestada"} =
                 json_response(get(conn, ~p"/api/chaves/#{chave}"), 200)["data"]
      end
    end

    test "409 sem registrar nada quando uma chave não está disponível", %{
      conn: conn,
      admin: admin
    } do
      livre = chave_fixture()
      emprestimo = emprestimo_fixture(admin: admin)
      usuario = usuario_fixture()

      resposta =
        post(conn, ~p"/api/emprestimos/lote",
          chave_ids: [livre.id, emprestimo.chave.id],
          usuario_id: usuario.id
        )

      detalhe = json_response(resposta, 409)["errors"]["detail"]
      assert detalhe == "a chave #{emprestimo.chave.codigo} não está disponível"

      assert %{"status" => "disponivel"} =
               json_response(get(conn, ~p"/api/chaves/#{livre}"), 200)["data"]

      assert %{"meta" => %{"total" => 0}} =
               json_response(get(conn, ~p"/api/emprestimos", usuario_id: usuario.id), 200)
    end

    test "422 sem chaves, com chaves demais ou com id inválido", %{conn: conn} do
      usuario = usuario_fixture()
      demais = for _ <- 1..21, do: Ecto.UUID.generate()

      for chave_ids <- [[], demais, "nao-e-lista"] do
        resposta =
          post(conn, ~p"/api/emprestimos/lote", chave_ids: chave_ids, usuario_id: usuario.id)

        assert %{"detail" => _} = json_response(resposta, 422)["errors"]
      end

      resposta = post(conn, ~p"/api/emprestimos/lote", chave_ids: ["x"], usuario_id: usuario.id)
      assert %{"chave_id" => _} = json_response(resposta, 422)["errors"]
    end
  end

  describe "chaves restritas" do
    setup do
      %{chave: chave_fixture(restrita: true), usuario: usuario_fixture()}
    end

    test "422 para quem não está na lista", %{conn: conn, chave: chave, usuario: usuario} do
      resposta = post(conn, ~p"/api/emprestimos", chave_id: chave.id, usuario_id: usuario.id)

      assert %{"detail" => detalhe} = json_response(resposta, 422)["errors"]
      assert detalhe =~ usuario.nome and detalhe =~ chave.codigo

      assert %{"status" => "disponivel"} =
               json_response(get(conn, ~p"/api/chaves/#{chave}"), 200)["data"]
    end

    test "201 para quem está na lista", ctx do
      %{conn: conn, chave: chave, usuario: usuario, admin: admin} = ctx
      {:ok, _} = Unlokao.Chaves.autorizar(chave, %{usuario_id: usuario.id}, admin)

      resposta = post(conn, ~p"/api/emprestimos", chave_id: chave.id, usuario_id: usuario.id)
      assert json_response(resposta, 201)
    end

    test "autorização vencida não vale, e a do último dia vale", ctx do
      %{conn: conn, chave: chave, usuario: usuario, admin: admin} = ctx
      hoje = Date.utc_today()

      {:ok, autorizacao} =
        Unlokao.Chaves.autorizar(
          chave,
          %{usuario_id: usuario.id, valida_ate: Date.add(hoje, -1)},
          admin
        )

      resposta = post(conn, ~p"/api/emprestimos", chave_id: chave.id, usuario_id: usuario.id)
      assert json_response(resposta, 422)

      autorizacao |> Ecto.Changeset.change(valida_ate: hoje) |> Unlokao.Repo.update!()

      resposta = post(conn, ~p"/api/emprestimos", chave_id: chave.id, usuario_id: usuario.id)
      assert json_response(resposta, 201)
    end

    test "o admin também precisa estar na lista", %{conn: conn, chave: chave, admin: admin} do
      resposta = post(conn, ~p"/api/emprestimos", chave_id: chave.id, usuario_id: admin.id)
      assert json_response(resposta, 422)
    end

    test "no lote, uma chave proibida barra todas", %{conn: conn, chave: chave, usuario: usuario} do
      livre = chave_fixture()

      resposta =
        post(conn, ~p"/api/emprestimos/lote",
          chave_ids: [livre.id, chave.id],
          usuario_id: usuario.id
        )

      assert %{"detail" => detalhe} = json_response(resposta, 422)["errors"]
      assert detalhe =~ chave.codigo

      assert %{"status" => "disponivel"} =
               json_response(get(conn, ~p"/api/chaves/#{livre}"), 200)["data"]
    end

    test "devolver não depende da lista", ctx do
      %{conn: conn, chave: chave, usuario: usuario, admin: admin} = ctx
      {:ok, autorizacao} = Unlokao.Chaves.autorizar(chave, %{usuario_id: usuario.id}, admin)
      emprestimo = emprestimo_fixture(admin: admin, chave_id: chave.id, usuario_id: usuario.id)
      {:ok, _} = Unlokao.Chaves.remover_autorizacao(chave, autorizacao.id)

      assert json_response(post(conn, ~p"/api/emprestimos/#{emprestimo}/devolucao"), 200)
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

    test "aceita usuario_id de quem devolveu, diferente de quem retirou", %{
      conn: conn,
      admin: admin
    } do
      emprestimo = emprestimo_fixture(admin: admin)
      colega = usuario_fixture()

      resposta =
        conn
        |> post(~p"/api/emprestimos/#{emprestimo}/devolucao", usuario_id: colega.id)
        |> json_response(200)

      assert resposta["data"]["devolvido_por"]["id"] == colega.id
      assert resposta["data"]["usuario"]["id"] == emprestimo.usuario.id
    end

    test "422 com usuario_id de quem devolveu inexistente", %{conn: conn, admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)

      conn =
        post(conn, ~p"/api/emprestimos/#{emprestimo}/devolucao", usuario_id: Ecto.UUID.generate())

      assert json_response(conn, 422)["errors"]["detail"]
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
