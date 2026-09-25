defmodule UnlokaoWeb.ApiDoc do
  @moduledoc "Trechos repetidos da documentação OpenAPI dos controllers."

  alias OpenApiSpex.Schema
  alias UnlokaoWeb.Schemas

  @erros %{
    nao_autenticado: {:unauthorized, "Sem login, token inválido ou expirado"},
    proibido: {:forbidden, "Rota só para administradores"},
    nao_encontrado: {:not_found, "Registro não existe, foi excluído ou o id é inválido"},
    conflito: {:conflict, "Valor duplicado ou conflito com o estado atual"},
    validacao: {:unprocessable_entity, "Campo obrigatório ausente ou valor inválido"},
    muitas_tentativas: {:too_many_requests, "Muitas tentativas; ver o cabeçalho Retry-After"}
  }

  @doc "Respostas de erro, na forma aceita por `operation responses:`."
  def erros(tipos) do
    for tipo <- tipos do
      {status, descricao} = Map.fetch!(@erros, tipo)
      {status, {descricao, "application/json", Schemas.Erro}}
    end
  end

  @doc "Erros de toda rota de admin, somados aos `extras`."
  def erros_admin(extras \\ []), do: erros([:nao_autenticado, :proibido | extras])

  def json(descricao, schema), do: {descricao, "application/json", schema}

  def corpo(schema), do: {"Corpo JSON", "application/json", schema, required: true}

  def id(descricao \\ "Id (UUID)"),
    do: [id: [in: :path, schema: %Schema{type: :string, format: :uuid}, description: descricao]]

  @doc "Parâmetros `pagina` e `por_pagina`, somados aos filtros da listagem."
  def paginacao(filtros \\ []) do
    [
      pagina: [
        in: :query,
        schema: %Schema{type: :integer, minimum: 1, default: 1},
        description: "Página"
      ],
      por_pagina: [
        in: :query,
        schema: %Schema{type: :integer, minimum: 1, maximum: 100, default: 20},
        description: "Itens por página"
      ]
    ] ++ filtros
  end

  def filtro(descricao, schema), do: [in: :query, schema: schema, description: descricao]
end
