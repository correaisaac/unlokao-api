defmodule Unlokao.ChavesTest do
  use Unlokao.DataCase

  alias Unlokao.Chaves
  alias Unlokao.Chaves.Chave

  import Unlokao.ChavesFixtures

  describe "create_chave/1 (#2)" do
    test "cria a chave como disponível e ativa" do
      assert {:ok, %Chave{} = chave} =
               Chaves.create_chave(%{codigo: " LAB-101-A ", espaco: "Laboratório 101"})

      assert chave.codigo == "LAB-101-A"
      assert chave.status == :disponivel
      assert chave.ativo
    end

    test "exige código e espaço" do
      assert {:error, changeset} = Chaves.create_chave(%{})
      assert %{codigo: ["can't be blank"], espaco: ["can't be blank"]} = errors_on(changeset)
    end

    test "ignora status enviado no cadastro" do
      {:ok, chave} = Chaves.create_chave(%{codigo: "X-1", espaco: "Sala 1", status: "emprestada"})
      assert chave.status == :disponivel
    end

    test "não aceita código duplicado entre chaves ativas" do
      chave_fixture(codigo: "LAB-1")
      assert {:error, changeset} = Chaves.create_chave(%{codigo: "LAB-1", espaco: "Outra sala"})
      assert %{codigo: ["já está em uso por outra chave"]} = errors_on(changeset)
    end

    test "permite reutilizar o código de uma chave excluída" do
      chave = chave_fixture(codigo: "LAB-1")
      {:ok, _} = Chaves.delete_chave(chave)
      assert {:ok, %Chave{}} = Chaves.create_chave(%{codigo: "LAB-1", espaco: "Sala nova"})
    end
  end

  describe "update_chave/2 (#3)" do
    test "atualiza os dados e permite marcar como indisponível" do
      chave = chave_fixture()

      assert {:ok, chave} =
               Chaves.update_chave(chave, %{espaco: "Auditório", status: "indisponivel"})

      assert chave.espaco == "Auditório"
      assert chave.status == :indisponivel
    end

    test "não deixa marcar como emprestada à mão" do
      chave = chave_fixture()
      assert {:error, changeset} = Chaves.update_chave(chave, %{status: "emprestada"})
      assert %{status: [_]} = errors_on(changeset)
    end

    test "não deixa tirar uma chave do status emprestada à mão" do
      chave = chave_emprestada_fixture()
      assert {:error, changeset} = Chaves.update_chave(chave, %{status: "disponivel"})
      assert %{status: [_]} = errors_on(changeset)
    end
  end

  describe "delete_chave/1 (#4)" do
    test "exclui logicamente: some da listagem e da busca" do
      chave = chave_fixture()
      assert {:ok, %Chave{ativo: false}} = Chaves.delete_chave(chave)
      assert Chaves.list_chaves() == []
      assert Chaves.fetch_chave(chave.id) == {:error, :not_found}
      assert Repo.get(Chave, chave.id), "o registro continua no banco para o histórico"
    end

    test "não exclui chave emprestada" do
      chave = chave_emprestada_fixture()
      assert {:error, {:conflict, _}} = Chaves.delete_chave(chave)
    end
  end
end
