defmodule UnlokaoWeb.ChaveJSON do
  alias Unlokao.Chaves.Chave

  def index(%{pagina: pagina}) do
    UnlokaoWeb.PaginacaoJSON.render(pagina, &data/1)
  end

  def show(%{chave: chave}) do
    %{data: data(chave)}
  end

  defp data(%Chave{} = chave) do
    %{
      id: chave.id,
      codigo: chave.codigo,
      espaco: chave.espaco,
      bloco: chave.bloco,
      descricao: chave.descricao,
      status: chave.status,
      inserted_at: chave.inserted_at,
      updated_at: chave.updated_at
    }
  end
end
