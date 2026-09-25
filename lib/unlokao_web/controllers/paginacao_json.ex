defmodule UnlokaoWeb.PaginacaoJSON do
  @moduledoc "Formato padrão das listagens: `%{data: [...], meta: %{...}}`."

  alias Unlokao.Paginacao

  def render(%Paginacao{} = pagina, fun) do
    %{
      data: Enum.map(pagina.itens, fun),
      meta: %{
        pagina: pagina.pagina,
        por_pagina: pagina.por_pagina,
        total: pagina.total,
        total_paginas: pagina.total_paginas
      }
    }
  end
end
