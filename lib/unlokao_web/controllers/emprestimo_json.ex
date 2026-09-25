defmodule UnlokaoWeb.EmprestimoJSON do
  alias Unlokao.Emprestimos.Emprestimo

  def index(%{pagina: pagina}) do
    UnlokaoWeb.PaginacaoJSON.render(pagina, &data/1)
  end

  def show(%{emprestimo: emprestimo}) do
    %{data: data(emprestimo)}
  end

  defp data(%Emprestimo{} = emprestimo) do
    %{
      id: emprestimo.id,
      chave: %{
        id: emprestimo.chave.id,
        codigo: emprestimo.chave.codigo,
        espaco: emprestimo.chave.espaco,
        bloco: emprestimo.chave.bloco
      },
      usuario: pessoa(emprestimo.usuario),
      entregue_por: pessoa(emprestimo.entregue_por),
      recebido_por: pessoa(emprestimo.recebido_por),
      retirada_em: emprestimo.retirada_em,
      prazo: emprestimo.prazo,
      devolvida_em: emprestimo.devolvida_em,
      atrasado: Emprestimo.atrasado?(emprestimo),
      observacao: emprestimo.observacao
    }
  end

  defp pessoa(nil), do: nil

  defp pessoa(usuario) do
    %{id: usuario.id, nome: usuario.nome, email: usuario.email, matricula: usuario.matricula}
  end
end
