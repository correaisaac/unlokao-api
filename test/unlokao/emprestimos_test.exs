defmodule Unlokao.EmprestimosTest do
  use Unlokao.DataCase
  use Oban.Testing, repo: Unlokao.Repo

  alias Unlokao.{Chaves, Emprestimos, Usuarios}
  alias Unlokao.Emprestimos.Emprestimo

  import Unlokao.ChavesFixtures
  import Unlokao.EmprestimosFixtures
  import Unlokao.UsuariosFixtures

  setup do
    %{admin: usuario_fixture(perfil: :admin)}
  end

  describe "registrar_emprestimo/2 (#18)" do
    test "empresta a chave com prazo padrão de 4 horas", %{admin: admin} do
      chave = chave_fixture()
      usuario = usuario_fixture()

      assert {:ok, %Emprestimo{} = emprestimo} =
               Emprestimos.registrar_emprestimo(
                 %{chave_id: chave.id, usuario_id: usuario.id},
                 admin
               )

      assert emprestimo.entregue_por.id == admin.id
      assert emprestimo.usuario.id == usuario.id
      assert DateTime.diff(emprestimo.prazo, emprestimo.retirada_em, :hour) == 4
      assert {:ok, %{status: :emprestada}} = Chaves.fetch_chave(chave.id)
    end

    test "aceita um prazo no futuro e recusa no passado", %{admin: admin} do
      prazo = DateTime.utc_now(:second) |> DateTime.add(1, :day)
      emprestimo = emprestimo_fixture(admin: admin, prazo: prazo, observacao: "aula extra")
      assert emprestimo.prazo == prazo
      assert emprestimo.observacao == "aula extra"

      attrs = %{
        chave_id: chave_fixture().id,
        usuario_id: usuario_fixture().id,
        prazo: ~U[2020-01-01 00:00:00Z]
      }

      assert {:error, changeset} = Emprestimos.registrar_emprestimo(attrs, admin)
      assert %{prazo: [_]} = errors_on(changeset)
    end

    test "exige chave e usuário existentes e ativos", %{admin: admin} do
      assert {:error, changeset} = Emprestimos.registrar_emprestimo(%{}, admin)
      assert %{chave_id: [_], usuario_id: [_]} = errors_on(changeset)

      usuario = usuario_fixture()
      attrs = %{chave_id: Ecto.UUID.generate(), usuario_id: usuario.id}
      assert {:error, changeset} = Emprestimos.registrar_emprestimo(attrs, admin)
      assert %{chave_id: ["não encontrada"]} = errors_on(changeset)

      {:ok, _} = Usuarios.delete_usuario(usuario, admin)

      assert {:error, changeset} =
               Emprestimos.registrar_emprestimo(%{attrs | chave_id: chave_fixture().id}, admin)

      assert %{usuario_id: ["não encontrado"]} = errors_on(changeset)
    end

    test "não empresta chave emprestada ou indisponível", %{admin: admin} do
      emprestada = emprestimo_fixture(admin: admin).chave
      {:ok, indisponivel} = Chaves.update_chave(chave_fixture(), %{status: "indisponivel"})

      for chave <- [emprestada, indisponivel] do
        attrs = %{chave_id: chave.id, usuario_id: usuario_fixture().id}

        assert {:error, {:conflict, "a chave não está disponível"}} =
                 Emprestimos.registrar_emprestimo(attrs, admin)
      end
    end

    test "falha no empréstimo não deixa a chave presa como emprestada", %{admin: admin} do
      chave = chave_fixture()
      attrs = %{chave_id: chave.id, usuario_id: Ecto.UUID.generate()}

      assert {:error, _} = Emprestimos.registrar_emprestimo(attrs, admin)
      assert {:ok, %{status: :disponivel}} = Chaves.fetch_chave(chave.id)
    end

    test "o banco recusa dois empréstimos abertos para a mesma chave", %{admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)
      agora = DateTime.utc_now(:second)

      # Simula uma segunda retirada que tivesse passado pela checagem de status.
      changeset =
        Emprestimo.retirada_changeset(
          %Emprestimo{entregue_por_id: admin.id, retirada_em: agora},
          %{chave_id: emprestimo.chave.id, usuario_id: usuario_fixture().id}
        )

      assert {:error, changeset} = Repo.insert(changeset)
      assert %{chave_id: ["já está emprestada"]} = errors_on(changeset)
    end
  end

  describe "registrar_devolucao/2 (#19)" do
    test "devolve a chave, que volta a ficar disponível", %{admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)
      porteiro = usuario_fixture(perfil: :admin)

      assert {:ok, devolvido} = Emprestimos.registrar_devolucao(emprestimo, porteiro)
      assert devolvido.devolvida_em
      assert devolvido.recebido_por.id == porteiro.id
      assert {:ok, %{status: :disponivel}} = Chaves.fetch_chave(emprestimo.chave.id)

      assert {:ok, _} =
               Emprestimos.registrar_emprestimo(
                 %{chave_id: emprestimo.chave.id, usuario_id: usuario_fixture().id},
                 admin
               )
    end

    test "não devolve duas vezes", %{admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)
      {:ok, _} = Emprestimos.registrar_devolucao(emprestimo, admin)

      assert {:error, {:conflict, _}} = Emprestimos.registrar_devolucao(emprestimo, admin)
    end
  end

  describe "consultas (#20)" do
    test "filtra por situação, chave e usuário, do mais recente para o mais antigo", %{
      admin: admin
    } do
      atrasado = emprestimo_fixture(admin: admin) |> atrasar()
      # Retirado 10 minutos atrás, para a ordem não depender de empate no mesmo segundo.
      aberto =
        emprestimo_fixture(admin: admin)
        |> Ecto.Changeset.change(
          retirada_em: DateTime.add(DateTime.utc_now(:second), -10, :minute)
        )
        |> Repo.update!()

      devolvido = emprestimo_fixture(admin: admin)
      {:ok, _} = Emprestimos.registrar_devolucao(devolvido, admin)

      ids = fn params ->
        {:ok, pagina} = Emprestimos.list_emprestimos(params)
        Enum.map(pagina.itens, & &1.id)
      end

      assert ids.(%{}) == [devolvido.id, aberto.id, atrasado.id]
      assert ids.(%{"situacao" => "aberto"}) == [aberto.id, atrasado.id]
      assert ids.(%{"situacao" => "atrasado"}) == [atrasado.id]
      assert ids.(%{"situacao" => "devolvido"}) == [devolvido.id]
      assert ids.(%{"chave_id" => aberto.chave.id}) == [aberto.id]
      assert ids.(%{"usuario_id" => atrasado.usuario.id}) == [atrasado.id]
      assert {:error, %Ecto.Changeset{}} = Emprestimos.list_emprestimos(%{"usuario_id" => "x"})
    end

    test "atrasado?/1" do
      agora = DateTime.utc_now()
      passado = DateTime.add(agora, -1, :hour)
      futuro = DateTime.add(agora, 1, :hour)

      assert Emprestimo.atrasado?(%Emprestimo{prazo: passado})
      refute Emprestimo.atrasado?(%Emprestimo{prazo: futuro})
      refute Emprestimo.atrasado?(%Emprestimo{prazo: passado, devolvida_em: agora})
    end

    test "list_emprestimos_do_usuario/2 só traz os do usuário", %{admin: admin} do
      meu = emprestimo_fixture(admin: admin)
      _outro = emprestimo_fixture(admin: admin)

      params = %{"usuario_id" => Ecto.UUID.generate()}

      assert {:ok, %{itens: [%{id: id}]}} =
               Emprestimos.list_emprestimos_do_usuario(meu.usuario, params)

      assert id == meu.id
    end
  end

  describe "avisar_atrasos/0 (#22)" do
    import Swoosh.TestAssertions

    test "avisa cada atrasado uma única vez", %{admin: admin} do
      atrasado = emprestimo_fixture(admin: admin) |> atrasar()
      _em_dia = emprestimo_fixture(admin: admin)
      devolvido_atrasado = emprestimo_fixture(admin: admin) |> atrasar()
      {:ok, _} = Emprestimos.registrar_devolucao(devolvido_atrasado, admin)

      assert {:ok, 1} = Emprestimos.avisar_atrasos()

      assert_email_sent(fn email ->
        assert email.to == [{atrasado.usuario.nome, atrasado.usuario.email}]
        assert email.subject =~ atrasado.chave.codigo
      end)

      assert {:ok, 0} = Emprestimos.avisar_atrasos()
      assert_no_email_sent()
    end

    test "o job do Oban executa o aviso", %{admin: admin} do
      emprestimo_fixture(admin: admin) |> atrasar()
      assert :ok = perform_job(Unlokao.Emprestimos.AvisarAtrasos, %{})
      assert_email_sent()
    end
  end

  describe "exclusão de usuário com chave (#21)" do
    test "bloqueia enquanto a chave não for devolvida", %{admin: admin} do
      emprestimo = emprestimo_fixture(admin: admin)
      usuario = emprestimo.usuario

      assert {:error, {:conflict, _}} = Usuarios.delete_usuario(usuario, admin)
      {:ok, _} = Emprestimos.registrar_devolucao(emprestimo, admin)
      assert {:ok, _} = Usuarios.delete_usuario(usuario, admin)
    end
  end
end
