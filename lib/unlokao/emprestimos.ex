defmodule Unlokao.Emprestimos do
  @moduledoc """
  Empréstimo e devolução das chaves: o núcleo do Unlokao.
  """

  import Ecto.Query, warn: false
  alias Unlokao.Repo

  alias Unlokao.Chaves.Chave
  alias Unlokao.Emprestimos.{Emprestimo, Notificador}
  alias Unlokao.Paginacao
  alias Unlokao.Usuarios.Usuario

  @relacoes [:chave, :usuario, :entregue_por, :recebido_por]

  @doc """
  Lista os empréstimos, do mais recente para o mais antigo, com paginação.

  Filtros: `situacao` (`aberto`, `atrasado`, `devolvido`), `chave_id` e `usuario_id`.
  """
  def list_emprestimos(params \\ %{}) do
    filtros = %{
      situacao: Paginacao.enum([:aberto, :atrasado, :devolvido]),
      chave_id: Ecto.UUID,
      usuario_id: Ecto.UUID
    }

    with {:ok, params} <- Paginacao.validar(params, filtros) do
      query =
        Enum.reduce(params, Emprestimo, fn
          {:situacao, :aberto}, query ->
            where(query, [e], is_nil(e.devolvida_em))

          {:situacao, :atrasado}, query ->
            where(query, [e], is_nil(e.devolvida_em) and e.prazo < ^DateTime.utc_now())

          {:situacao, :devolvido}, query ->
            where(query, [e], not is_nil(e.devolvida_em))

          {:chave_id, id}, query ->
            where(query, chave_id: ^id)

          {:usuario_id, id}, query ->
            where(query, usuario_id: ^id)

          _, query ->
            query
        end)

      {:ok,
       query
       |> order_by(desc: :retirada_em, desc: :id)
       |> preload(^@relacoes)
       |> Paginacao.paginar(params)}
    end
  end

  @doc "Empréstimos de um usuário (para `GET /api/me/emprestimos`)."
  def list_emprestimos_do_usuario(%Usuario{id: id}, params) do
    params
    |> Map.drop(["usuario_id", :usuario_id])
    |> Map.put("usuario_id", id)
    |> list_emprestimos()
  end

  @doc "Busca um empréstimo. Retorna `{:error, :not_found}` se não existir ou o id for inválido."
  def fetch_emprestimo(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Emprestimo{} = emprestimo <- Repo.get(Emprestimo, uuid) do
      {:ok, Repo.preload(emprestimo, @relacoes)}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "O usuário está com alguma chave não devolvida?"
  def emprestimo_aberto?(%Usuario{id: id}) do
    Repo.exists?(from e in Emprestimo, where: e.usuario_id == ^id and is_nil(e.devolvida_em))
  end

  @doc """
  Registra a retirada de uma chave (#18) por `admin`.

  A chave precisa estar ativa e `disponivel`, e o usuário, ativo. A chave passa
  para `emprestada` na mesma transação.
  """
  def registrar_emprestimo(attrs, %Usuario{} = admin) do
    agora = DateTime.utc_now(:second)

    changeset =
      Emprestimo.retirada_changeset(
        %Emprestimo{entregue_por_id: admin.id, retirada_em: agora},
        attrs
      )

    Repo.transaction(fn ->
      with {:ok, dados} <- Ecto.Changeset.apply_action(changeset, :insert),
           :ok <- verificar_usuario(dados.usuario_id, changeset),
           :ok <- reservar_chave(dados.chave_id, agora, changeset),
           {:ok, emprestimo} <- Repo.insert(changeset) do
        Repo.preload(emprestimo, @relacoes)
      else
        {:error, erro} -> Repo.rollback(erro)
      end
    end)
  end

  @doc """
  Registra a devolução (#19) por `admin`. A chave volta a ficar `disponivel`.
  """
  def registrar_devolucao(%Emprestimo{} = emprestimo, %Usuario{} = admin) do
    agora = DateTime.utc_now(:second)

    Repo.transaction(fn ->
      # Condicional para que duas devoluções simultâneas não passem as duas.
      {devolvidos, _} =
        from(e in Emprestimo, where: e.id == ^emprestimo.id and is_nil(e.devolvida_em))
        |> Repo.update_all(
          set: [devolvida_em: agora, recebido_por_id: admin.id, updated_at: agora]
        )

      if devolvidos == 0, do: Repo.rollback({:conflict, "este empréstimo já foi devolvido"})

      from(c in Chave, where: c.id == ^emprestimo.chave_id)
      |> Repo.update_all(set: [status: :disponivel, updated_at: agora])

      Emprestimo |> Repo.get!(emprestimo.id) |> Repo.preload(@relacoes)
    end)
  end

  @doc """
  Manda um e-mail para cada empréstimo atrasado que ainda não foi avisado (#22).
  Se o envio falhar, o empréstimo continua pendente e é tentado de novo na próxima rodada.
  """
  def avisar_atrasos do
    agora = DateTime.utc_now(:second)

    avisados =
      from(e in Emprestimo,
        where: is_nil(e.devolvida_em) and e.prazo < ^agora and is_nil(e.atraso_avisado_em),
        preload: [:chave, :usuario]
      )
      |> Repo.all()
      |> Enum.filter(&match?({:ok, _}, Notificador.enviar_aviso_de_atraso(&1)))

    ids = Enum.map(avisados, & &1.id)
    Repo.update_all(from(e in Emprestimo, where: e.id in ^ids), set: [atraso_avisado_em: agora])

    {:ok, length(avisados)}
  end

  defp verificar_usuario(usuario_id, changeset) do
    if Repo.exists?(from u in Usuario, where: u.id == ^usuario_id and u.ativo),
      do: :ok,
      else: {:error, Ecto.Changeset.add_error(changeset, :usuario_id, "não encontrado")}
  end

  # UPDATE condicional: se duas retiradas da mesma chave chegarem juntas, o
  # Postgres serializa as duas e só a primeira encontra a chave `disponivel`.
  defp reservar_chave(chave_id, agora, changeset) do
    {reservadas, _} =
      from(c in Chave, where: c.id == ^chave_id and c.ativo and c.status == :disponivel)
      |> Repo.update_all(set: [status: :emprestada, updated_at: agora])

    cond do
      reservadas == 1 ->
        :ok

      Repo.exists?(from c in Chave, where: c.id == ^chave_id and c.ativo) ->
        {:error, {:conflict, "a chave não está disponível"}}

      true ->
        {:error, Ecto.Changeset.add_error(changeset, :chave_id, "não encontrada")}
    end
  end
end
