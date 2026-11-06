defmodule UnlokaoWeb.AutorizacaoControllerTest do
  use UnlokaoWeb.ConnCase

  import Unlokao.ChavesFixtures
  import Unlokao.UsuariosFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup :autenticar_admin

  setup do
    %{chave: chave_fixture(restrita: true), usuario: usuario_fixture()}
  end

  test "admin adiciona, lista e remove", ctx do
    %{conn: conn, chave: chave, usuario: usuario, admin: admin} = ctx

    resposta =
      post(conn, ~p"/api/chaves/#{chave}/autorizacoes",
        usuario_id: usuario.id,
        valida_ate: "2099-12-31"
      )

    assert %{
             "id" => id,
             "usuario" => %{"id" => usuario_id},
             "autorizado_por" => %{"id" => admin_id},
             "valida_ate" => "2099-12-31",
             "vigente" => true
           } = json_response(resposta, 201)["data"]

    assert usuario_id == usuario.id
    assert admin_id == admin.id

    assert [%{"id" => ^id}] =
             json_response(get(conn, ~p"/api/chaves/#{chave}/autorizacoes"), 200)["data"]

    assert response(delete(conn, ~p"/api/chaves/#{chave}/autorizacoes/#{id}"), 204)
    assert [] = json_response(get(conn, ~p"/api/chaves/#{chave}/autorizacoes"), 200)["data"]
  end

  test "filtra por usuário", %{conn: conn, chave: chave, usuario: usuario, admin: admin} do
    {:ok, _} = Unlokao.Chaves.autorizar(chave, %{usuario_id: usuario.id}, admin)

    assert [_] =
             conn
             |> get(~p"/api/chaves/#{chave}/autorizacoes", usuario_id: usuario.id)
             |> json_response(200)
             |> Map.get("data")

    assert [] =
             conn
             |> get(~p"/api/chaves/#{chave}/autorizacoes", usuario_id: admin.id)
             |> json_response(200)
             |> Map.get("data")
  end

  test "409 para quem já está na lista", %{conn: conn, chave: chave, usuario: usuario} do
    post(conn, ~p"/api/chaves/#{chave}/autorizacoes", usuario_id: usuario.id)

    resposta = post(conn, ~p"/api/chaves/#{chave}/autorizacoes", usuario_id: usuario.id)
    assert %{"usuario_id" => _} = json_response(resposta, 409)["errors"]
  end

  test "422 para pessoa inexistente ou id inválido", %{conn: conn, chave: chave} do
    for usuario_id <- [Ecto.UUID.generate(), "x"] do
      resposta = post(conn, ~p"/api/chaves/#{chave}/autorizacoes", usuario_id: usuario_id)
      assert %{"usuario_id" => _} = json_response(resposta, 422)["errors"]
    end
  end

  test "404 ao remover autorização de outra chave", ctx do
    %{conn: conn, chave: chave, usuario: usuario, admin: admin} = ctx
    {:ok, autorizacao} = Unlokao.Chaves.autorizar(chave, %{usuario_id: usuario.id}, admin)

    resposta = delete(conn, ~p"/api/chaves/#{chave_fixture()}/autorizacoes/#{autorizacao.id}")
    assert json_response(resposta, 404)
  end

  test "guarda consulta a lista, mas não altera", %{chave: chave, usuario: usuario} do
    guarda = autenticar(build_conn(), usuario_fixture(perfil: :guarda))

    assert json_response(get(guarda, ~p"/api/chaves/#{chave}/autorizacoes"), 200)

    resposta = post(guarda, ~p"/api/chaves/#{chave}/autorizacoes", usuario_id: usuario.id)
    assert json_response(resposta, 403)
  end

  test "usuário comum não vê a lista", %{chave: chave, usuario: usuario} do
    comum = autenticar(build_conn(), usuario)
    assert json_response(get(comum, ~p"/api/chaves/#{chave}/autorizacoes"), 403)
  end
end
