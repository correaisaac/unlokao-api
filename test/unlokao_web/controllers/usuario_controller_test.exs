defmodule UnlokaoWeb.UsuarioControllerTest do
  use UnlokaoWeb.ConnCase

  import Unlokao.UsuariosFixtures

  @valido %{
    nome: "Maria Silva",
    email: "maria@universidade.edu.br",
    matricula: "20231234",
    perfil: "aluno",
    senha: "senha-segura-123"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup :autenticar_admin

  test "GET /api/usuarios lista sem expor senha", %{conn: conn} do
    usuario_fixture()
    usuarios = conn |> get(~p"/api/usuarios") |> json_response(200) |> Map.fetch!("data")

    assert length(usuarios) == 2, "o usuário criado e o admin logado"

    for usuario <- usuarios do
      refute Map.has_key?(usuario, "senha")
      refute Map.has_key?(usuario, "senha_hash")
    end
  end

  describe "POST /api/usuarios" do
    test "201 com o usuário criado, sem senha", %{conn: conn} do
      conn = post(conn, ~p"/api/usuarios", @valido)
      data = json_response(conn, 201)["data"]

      assert %{"email" => "maria@universidade.edu.br", "perfil" => "aluno"} = data
      refute Map.has_key?(data, "senha_hash")
    end

    test "422 com dados inválidos", %{conn: conn} do
      conn = post(conn, ~p"/api/usuarios", %{@valido | email: "invalido"})
      assert %{"email" => _} = json_response(conn, 422)["errors"]
    end

    test "409 com e-mail duplicado", %{conn: conn} do
      usuario_fixture(email: @valido.email)
      conn = post(conn, ~p"/api/usuarios", @valido)
      assert %{"email" => _} = json_response(conn, 409)["errors"]
    end
  end

  describe "PATCH /api/usuarios/:id" do
    test "200 com o usuário atualizado", %{conn: conn} do
      usuario = usuario_fixture()
      conn = patch(conn, ~p"/api/usuarios/#{usuario}", telefone: "83 99999-0000")
      assert %{"telefone" => "83 99999-0000"} = json_response(conn, 200)["data"]
    end

    test "409 com matrícula de outro usuário", %{conn: conn} do
      outro = usuario_fixture()
      usuario = usuario_fixture()
      conn = patch(conn, ~p"/api/usuarios/#{usuario}", matricula: outro.matricula)
      assert %{"matricula" => _} = json_response(conn, 409)["errors"]
    end
  end

  test "DELETE /api/usuarios/:id retorna 204 e o usuário deixa de ser encontrado", %{conn: conn} do
    usuario = usuario_fixture()
    assert response(delete(conn, ~p"/api/usuarios/#{usuario}"), 204)
    assert json_response(get(conn, ~p"/api/usuarios/#{usuario}"), 404)
  end

  test "DELETE /api/usuarios/:id retorna 422 quando o admin tenta excluir a si mesmo",
       %{conn: conn, admin: admin} do
    conn = delete(conn, ~p"/api/usuarios/#{admin}")

    assert %{"detail" => "você não pode excluir o próprio usuário"} =
             json_response(conn, 422)["errors"]
  end

  describe "POST /api/cadastro" do
    @cadastro %{
      nome: "Maria Silva",
      email: "maria@universidade.edu.br",
      matricula: "20231234",
      perfil: "aluno",
      senha: "senha-segura-123"
    }

    setup do
      {:ok, publico: put_req_header(build_conn(), "accept", "application/json")}
    end

    test "cria a conta sem login e a pessoa já consegue entrar", %{publico: publico} do
      assert %{"perfil" => "aluno", "matricula" => "20231234"} =
               publico
               |> post(~p"/api/cadastro", @cadastro)
               |> json_response(201)
               |> Map.get("data")

      assert publico
             |> post(~p"/api/login", email: @cadastro.email, senha: @cadastro.senha)
             |> json_response(200)
    end

    test "422 ao pedir perfil de guarda ou admin", %{publico: publico} do
      for perfil <- ["guarda", "admin"] do
        resposta = post(publico, ~p"/api/cadastro", %{@cadastro | perfil: perfil})
        assert %{"perfil" => _} = json_response(resposta, 422)["errors"]
      end

      assert %{status: 401} =
               post(publico, ~p"/api/login", email: @cadastro.email, senha: @cadastro.senha)
    end

    test "409 com matrícula ou e-mail já usados", %{publico: publico} do
      post(publico, ~p"/api/cadastro", @cadastro)

      resposta =
        post(publico, ~p"/api/cadastro", %{@cadastro | email: "outra@universidade.edu.br"})

      assert %{"matricula" => _} = json_response(resposta, 409)["errors"]
    end

    test "422 com campos faltando", %{publico: publico} do
      resposta = post(publico, ~p"/api/cadastro", %{})
      assert %{"nome" => _, "email" => _, "senha" => _} = json_response(resposta, 422)["errors"]
    end
  end
end
