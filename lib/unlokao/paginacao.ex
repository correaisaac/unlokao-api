defmodule Unlokao.Paginacao do
  @moduledoc """
  Filtros e paginação das listagens.

  Os parâmetros chegam como texto na query string (`?pagina=2&status=disponivel`)
  e são validados com um changeset: valor inválido vira erro 422.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Unlokao.Repo

  defstruct [:itens, :pagina, :por_pagina, :total, :total_paginas]

  @por_pagina_padrao 20
  @por_pagina_maximo 100

  @doc """
  Valida `pagina`, `por_pagina` e os filtros de cada listagem.

  `filtros` é um mapa `%{nome: tipo_ecto}`. Retorna `{:ok, mapa}` só com os
  parâmetros enviados (mais os padrões de paginação) ou `{:error, changeset}`.
  """
  def validar(params, filtros \\ %{}) do
    tipos = Map.merge(%{pagina: :integer, por_pagina: :integer}, filtros)

    {%{pagina: 1, por_pagina: @por_pagina_padrao}, tipos}
    |> cast(params, Map.keys(tipos))
    |> validate_number(:pagina, greater_than: 0)
    |> validate_number(:por_pagina, greater_than: 0, less_than_or_equal_to: @por_pagina_maximo)
    |> apply_action(:listar)
  end

  @doc "Tipo Ecto para filtros com valores fixos (ex.: status, perfil)."
  def enum(valores), do: Ecto.ParameterizedType.init(Ecto.Enum, values: valores)

  @doc "Executa a query paginada."
  def paginar(query, %{pagina: pagina, por_pagina: por_pagina}) do
    total = query |> exclude(:order_by) |> exclude(:preload) |> Repo.aggregate(:count)

    itens =
      query
      |> limit(^por_pagina)
      |> offset(^((pagina - 1) * por_pagina))
      |> Repo.all()

    %__MODULE__{
      itens: itens,
      pagina: pagina,
      por_pagina: por_pagina,
      total: total,
      total_paginas: max(ceil(total / por_pagina), 1)
    }
  end

  @doc "Padrão para `ilike` que procura o texto em qualquer posição, escapando `%` e `_`."
  def contem(texto) do
    "%" <> String.replace(texto, ~r/([\\%_])/, "\\\\\\1") <> "%"
  end
end
