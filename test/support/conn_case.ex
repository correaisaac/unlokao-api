defmodule UnlokaoWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use UnlokaoWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint UnlokaoWeb.Endpoint

      use UnlokaoWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import UnlokaoWeb.ConnCase
    end
  end

  setup tags do
    Unlokao.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Confere que a resposta (status e corpo) está descrita na documentação OpenAPI
  da rota que a gerou. Devolve o `conn` para encadear.
  """
  def assert_documentado(conn) do
    # Pela tabela de rotas, porque quando um plug do pipeline interrompe a
    # requisição (401, 403, 429) o controller nem chega a ser chamado.
    %{plug: controller, plug_opts: action} =
      Phoenix.Router.route_info(UnlokaoWeb.Router, conn.method, conn.request_path, conn.host)

    OpenApiSpex.TestAssertions.assert_operation_response(conn, "#{inspect(controller)}.#{action}")
  end

  @doc "Faz a requisição como `usuario`, com um token de sessão válido."
  def autenticar(conn, usuario) do
    token = Unlokao.Autenticacao.criar_token_de_sessao(usuario)
    Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> token)
  end

  @doc "Setup para testes que precisam de um admin logado. Use com `setup :autenticar_admin`."
  def autenticar_admin(%{conn: conn}) do
    admin = Unlokao.UsuariosFixtures.usuario_fixture(perfil: :admin)
    %{conn: autenticar(conn, admin), admin: admin}
  end
end
