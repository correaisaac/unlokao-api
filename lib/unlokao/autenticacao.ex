defmodule Unlokao.Autenticacao do
  @moduledoc """
  Login, sessões e troca/redefinição de senha.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Unlokao.Repo

  alias Unlokao.Autenticacao.{Notificador, Token}
  alias Unlokao.Usuarios.Usuario

  ## Login

  @doc """
  Confere e-mail e senha de um usuário ativo.

  Qualquer falha devolve o mesmo erro, para não revelar quais e-mails existem.
  """
  def autenticar(email, senha) when is_binary(email) and is_binary(senha) do
    usuario = Repo.get_by(Usuario, email: Usuario.normalizar_email(email), ativo: true)

    cond do
      usuario && Pbkdf2.verify_pass(senha, usuario.senha_hash) ->
        {:ok, usuario}

      usuario ->
        {:error, :credenciais_invalidas}

      true ->
        # Gasta o mesmo tempo de uma verificação real (evita descobrir e-mails pelo tempo de resposta).
        Pbkdf2.no_user_verify()
        {:error, :credenciais_invalidas}
    end
  end

  def autenticar(_email, _senha), do: {:error, :credenciais_invalidas}

  ## Sessão

  @doc "Cria uma sessão e devolve o token para o cliente."
  def criar_token_de_sessao(%Usuario{} = usuario) do
    {token, registro} = Token.gerar(usuario, "sessao")
    Repo.insert!(registro)
    token
  end

  @doc "Usuário dono da sessão, ou `nil` se o token for inválido, expirado ou o usuário estiver desativado."
  def buscar_usuario_por_token_de_sessao(token) do
    case Token.usuario_da_sessao(token) do
      {:ok, query} -> Repo.one(query)
      :error -> nil
    end
  end

  @doc "Encerra uma sessão (logout)."
  def revogar_token_de_sessao(token) do
    with {:ok, query} <- Token.por_token(token, "sessao"), do: Repo.delete_all(query)
    :ok
  end

  ## Senha

  @doc """
  Troca a senha de um usuário logado. Encerra as outras sessões dele, mas
  mantém a sessão atual (`token_atual`).
  """
  def trocar_senha(%Usuario{} = usuario, senha_atual, attrs, token_atual) do
    changeset = Usuario.senha_changeset(usuario, attrs)

    changeset =
      if is_binary(senha_atual) and Pbkdf2.verify_pass(senha_atual, usuario.senha_hash),
        do: changeset,
        else: Ecto.Changeset.add_error(changeset, :senha_atual, "está incorreta")

    {:ok, sessao_atual} = Token.por_token(token_atual, "sessao")
    ids_mantidos = from(t in sessao_atual, select: t.id)

    outros_tokens =
      from(t in Token.do_usuario(usuario), where: t.id not in subquery(ids_mantidos))

    atualizar_senha(changeset, outros_tokens)
  end

  @doc """
  Envia o link de redefinição de senha se o e-mail for de um usuário ativo.
  Sempre devolve `:ok`, para não revelar quais e-mails estão cadastrados.

  `montar_url` recebe o token e devolve o link que vai no e-mail.
  """
  def solicitar_redefinicao_de_senha(email, montar_url) when is_binary(email) do
    if usuario = Repo.get_by(Usuario, email: Usuario.normalizar_email(email), ativo: true) do
      {token, registro} = Token.gerar(usuario, "redefinir_senha")
      Repo.insert!(registro)
      Notificador.enviar_redefinicao_de_senha(usuario, montar_url.(token))
    end

    :ok
  end

  def solicitar_redefinicao_de_senha(_email, _montar_url), do: :ok

  @doc """
  Redefine a senha a partir do token recebido por e-mail. O token só pode ser
  usado uma vez e todas as sessões do usuário são encerradas.
  """
  def redefinir_senha(token, attrs) do
    with {:ok, query} <- Token.usuario_da_redefinicao(token),
         %Usuario{} = usuario <- Repo.one(query) do
      usuario
      |> Usuario.senha_changeset(attrs)
      |> atualizar_senha(Token.do_usuario(usuario))
    else
      _ -> {:error, :token_invalido}
    end
  end

  defp atualizar_senha(changeset, tokens_para_apagar) do
    Multi.new()
    |> Multi.update(:usuario, changeset)
    |> Multi.delete_all(:tokens, tokens_para_apagar)
    |> Repo.transaction()
    |> case do
      {:ok, %{usuario: usuario}} -> {:ok, usuario}
      {:error, :usuario, changeset, _} -> {:error, changeset}
    end
  end
end
