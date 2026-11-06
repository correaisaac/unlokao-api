defmodule UnlokaoWeb.AutorizacaoJSON do
  alias Unlokao.Chaves.Autorizacao

  def index(%{pagina: pagina}) do
    UnlokaoWeb.PaginacaoJSON.render(pagina, &data/1)
  end

  def show(%{autorizacao: autorizacao}) do
    %{data: data(autorizacao)}
  end

  defp data(%Autorizacao{} = autorizacao) do
    %{
      id: autorizacao.id,
      usuario: pessoa(autorizacao.usuario),
      autorizado_por: pessoa(autorizacao.autorizado_por),
      valida_ate: autorizacao.valida_ate,
      vigente: Autorizacao.vigente?(autorizacao),
      inserted_at: autorizacao.inserted_at
    }
  end

  defp pessoa(nil), do: nil

  defp pessoa(usuario) do
    %{id: usuario.id, nome: usuario.nome, email: usuario.email, matricula: usuario.matricula}
  end
end
