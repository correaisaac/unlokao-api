defmodule UnlokaoWeb.Schemas.Base do
  @moduledoc """
  Funções usadas para montar os schemas de `UnlokaoWeb.Schemas`. Ficam num
  módulo separado porque os schemas são compilados antes das funções do módulo
  que os contém existirem.
  """
  alias OpenApiSpex.Schema

  @doc "Valores de `status` de uma chave, lidos do schema Ecto para não divergir."
  def status_chave, do: valores(Unlokao.Chaves.Chave, :status)

  @doc "Valores de `perfil` de um usuário, lidos do schema Ecto para não divergir."
  def perfis, do: valores(Unlokao.Usuarios.Usuario, :perfil)

  @doc "Resposta com um item: `%{data: item}`."
  def resposta(titulo, schema) do
    %Schema{
      title: titulo,
      type: :object,
      properties: %{data: schema},
      required: [:data]
    }
  end

  @doc "Resposta de listagem: `%{data: [item], meta: paginação}`."
  def lista(titulo, schema) do
    %Schema{
      title: titulo,
      type: :object,
      properties: %{data: %Schema{type: :array, items: schema}, meta: UnlokaoWeb.Schemas.Meta},
      required: [:data, :meta]
    }
  end

  defp valores(schema, campo), do: schema |> Ecto.Enum.values(campo) |> Enum.map(&to_string/1)
end
