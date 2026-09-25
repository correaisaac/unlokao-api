defmodule Unlokao.Autenticacao.Token do
  @moduledoc """
  Tokens de sessão (login) e de redefinição de senha.

  O cliente recebe o token em Base64; o banco guarda só o hash SHA-256 dele,
  então um vazamento do banco não expõe sessões válidas.
  """
  use Ecto.Schema
  import Ecto.Query

  alias Unlokao.Autenticacao.Token
  alias Unlokao.Usuarios.Usuario

  @tamanho 32
  @validade_sessao_em_horas 7 * 24
  @validade_redefinicao_em_horas 1

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "usuarios_tokens" do
    field :token, :binary
    field :contexto, :string
    field :enviado_para, :string
    belongs_to :usuario, Usuario

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Gera um token novo. Retorna `{token_para_o_cliente, %Token{}}`, com o
  `%Token{}` ainda por inserir.
  """
  def gerar(%Usuario{} = usuario, contexto) when contexto in ["sessao", "redefinir_senha"] do
    token = :crypto.strong_rand_bytes(@tamanho)

    {Base.url_encode64(token, padding: false),
     %Token{
       token: :crypto.hash(:sha256, token),
       contexto: contexto,
       enviado_para: if(contexto == "redefinir_senha", do: usuario.email),
       usuario_id: usuario.id
     }}
  end

  @doc "Query do usuário ativo dono de uma sessão ainda válida."
  def usuario_da_sessao(token) do
    with {:ok, query} <- por_token(token, "sessao") do
      {:ok,
       from(t in query,
         join: u in assoc(t, :usuario),
         where: u.ativo and t.inserted_at > ago(@validade_sessao_em_horas, "hour"),
         select: u
       )}
    end
  end

  @doc """
  Query do usuário ativo dono de um token de redefinição ainda válido.
  O token deixa de valer se o e-mail do usuário mudou depois do envio.
  """
  def usuario_da_redefinicao(token) do
    with {:ok, query} <- por_token(token, "redefinir_senha") do
      {:ok,
       from(t in query,
         join: u in assoc(t, :usuario),
         where: u.ativo and t.enviado_para == u.email,
         where: t.inserted_at > ago(@validade_redefinicao_em_horas, "hour"),
         select: u
       )}
    end
  end

  @doc "Query de um token específico. `:error` se o texto não for um token válido."
  def por_token(token, contexto) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, bruto} ->
        {:ok,
         from(t in Token,
           where: t.token == ^:crypto.hash(:sha256, bruto) and t.contexto == ^contexto
         )}

      :error ->
        :error
    end
  end

  def por_token(_token, _contexto), do: :error

  @doc "Query de todos os tokens de um usuário."
  def do_usuario(%Usuario{id: id}), do: from(t in Token, where: t.usuario_id == ^id)
end
