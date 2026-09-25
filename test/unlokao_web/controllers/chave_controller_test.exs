defmodule UnlokaoWeb.ChaveControllerTest do
  use UnlokaoWeb.ConnCase

  import Unlokao.ChavesFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup :autenticar_admin

  test "GET /api/chaves lista as chaves ativas", %{conn: conn} do
    chave = chave_fixture()

    assert [%{"id" => id}] =
             conn |> get(~p"/api/chaves") |> json_response(200) |> Map.fetch!("data")

    assert id == chave.id
  end

  describe "POST /api/chaves" do
    test "201 com a chave criada", %{conn: conn} do
      conn =
        post(conn, ~p"/api/chaves", codigo: "LAB-101-A", espaco: "Laboratório 101", bloco: "B")

      assert %{"id" => id, "codigo" => "LAB-101-A", "status" => "disponivel"} =
               json_response(conn, 201)["data"]

      assert get_resp_header(conn, "location") == ["/api/chaves/#{id}"]
    end

    test "422 sem campos obrigatórios", %{conn: conn} do
      conn = post(conn, ~p"/api/chaves", bloco: "B")
      assert %{"codigo" => _, "espaco" => _} = json_response(conn, 422)["errors"]
    end

    test "409 com código duplicado", %{conn: conn} do
      chave_fixture(codigo: "LAB-1")
      conn = post(conn, ~p"/api/chaves", codigo: "LAB-1", espaco: "Sala")
      assert %{"codigo" => _} = json_response(conn, 409)["errors"]
    end
  end

  test "GET /api/chaves/:id retorna 404 em JSON para id inválido", %{conn: conn} do
    conn = get(conn, ~p"/api/chaves/nao-e-uuid")
    assert %{"errors" => %{"detail" => "Not Found"}} = json_response(conn, 404)
  end

  describe "PATCH /api/chaves/:id" do
    test "200 com a chave atualizada", %{conn: conn} do
      chave = chave_fixture()
      conn = patch(conn, ~p"/api/chaves/#{chave}", espaco: "Auditório")
      assert %{"espaco" => "Auditório"} = json_response(conn, 200)["data"]
    end

    test "422 ao tentar marcar como emprestada", %{conn: conn} do
      chave = chave_fixture()
      conn = patch(conn, ~p"/api/chaves/#{chave}", status: "emprestada")
      assert %{"status" => _} = json_response(conn, 422)["errors"]
    end

    test "409 com código de outra chave", %{conn: conn} do
      chave_fixture(codigo: "LAB-1")
      chave = chave_fixture()
      conn = patch(conn, ~p"/api/chaves/#{chave}", codigo: "LAB-1")
      assert json_response(conn, 409)
    end

    test "404 para chave inexistente", %{conn: conn} do
      conn = patch(conn, ~p"/api/chaves/#{Ecto.UUID.generate()}", espaco: "X")
      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/chaves/:id" do
    test "204 e a chave deixa de ser encontrada", %{conn: conn} do
      chave = chave_fixture()
      assert response(delete(conn, ~p"/api/chaves/#{chave}"), 204)
      assert json_response(get(conn, ~p"/api/chaves/#{chave}"), 404)
    end

    test "409 para chave emprestada", %{conn: conn} do
      chave = chave_emprestada_fixture()
      conn = delete(conn, ~p"/api/chaves/#{chave}")
      assert %{"detail" => _} = json_response(conn, 409)["errors"]
    end
  end
end
