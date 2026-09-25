defmodule Unlokao.EmprestimosFixtures do
  @moduledoc "Helpers para criar empréstimos nos testes."

  import Unlokao.ChavesFixtures
  import Unlokao.UsuariosFixtures

  def emprestimo_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    admin = Map.get_lazy(attrs, :admin, fn -> usuario_fixture(perfil: :admin) end)

    {:ok, emprestimo} =
      attrs
      |> Map.delete(:admin)
      |> Map.put_new_lazy(:chave_id, fn -> chave_fixture().id end)
      |> Map.put_new_lazy(:usuario_id, fn -> usuario_fixture().id end)
      |> Unlokao.Emprestimos.registrar_emprestimo(admin)

    emprestimo
  end

  @doc "Move o prazo (e a retirada) para o passado, deixando o empréstimo atrasado."
  def atrasar(emprestimo, horas \\ 1) do
    agora = DateTime.utc_now(:second)

    emprestimo
    |> Ecto.Changeset.change(
      retirada_em: DateTime.add(agora, -(horas + 4), :hour),
      prazo: DateTime.add(agora, -horas, :hour)
    )
    |> Unlokao.Repo.update!()
  end
end
