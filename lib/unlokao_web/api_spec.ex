defmodule UnlokaoWeb.ApiSpec do
  @moduledoc """
  Especificação OpenAPI da API, montada a partir das rotas e das `operation`
  declaradas nos controllers. Servida em `GET /api/openapi`, com Swagger UI em `/api/docs`.
  """
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Unlokao API",
        version: "1.0.0",
        description: """
        API do Unlokao, sistema de empréstimo das chaves físicas dos espaços da universidade.

        Faça login em `POST /api/login` e envie o token recebido em
        `Authorization: Bearer <token>` nas demais rotas.
        """
      },
      paths: Paths.from_router(UnlokaoWeb.Router),
      components: %Components{
        securitySchemes: %{"token" => %SecurityScheme{type: "http", scheme: "bearer"}}
      },
      security: [%{"token" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
