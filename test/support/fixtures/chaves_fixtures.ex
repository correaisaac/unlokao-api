defmodule Unlokao.ChavesFixtures do
  @moduledoc "Helpers para criar chaves nos testes."

  def unique_chave_codigo, do: "LAB-#{System.unique_integer([:positive])}"

  def chave_fixture(attrs \\ %{}) do
    {:ok, chave} =
      attrs
      |> Enum.into(%{codigo: unique_chave_codigo(), espaco: "Laboratório 101", bloco: "B"})
      |> Unlokao.Chaves.create_chave()

    chave
  end

  @doc "Simula uma chave emprestada enquanto o fluxo de empréstimo não existe."
  def chave_emprestada_fixture(attrs \\ %{}) do
    attrs
    |> chave_fixture()
    |> Ecto.Changeset.change(status: :emprestada)
    |> Unlokao.Repo.update!()
  end
end
