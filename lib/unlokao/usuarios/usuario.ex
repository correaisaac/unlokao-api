defmodule Unlokao.Usuarios.Usuario do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "usuarios" do
    field :nome, :string
    field :email, :string
    field :matricula, :string
    field :telefone, :string
    field :perfil, Ecto.Enum, values: [:aluno, :professor, :servidor, :admin]
    field :senha, :string, virtual: true, redact: true
    field :senha_hash, :string, redact: true
    field :ativo, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc "Cadastro de um usuário novo (#6)."
  def create_changeset(usuario, attrs) do
    usuario
    |> cast(attrs, [:nome, :email, :matricula, :telefone, :perfil, :senha])
    |> validar_campos()
    |> validar_senha()
  end

  @doc "Troca ou redefinição de senha (#13, #14)."
  def senha_changeset(usuario, attrs) do
    usuario
    |> cast(attrs, [:senha])
    |> validar_senha()
  end

  @doc "Edição de um usuário (#7). A senha não muda por aqui: isso é do fluxo de login."
  def update_changeset(usuario, attrs) do
    usuario
    |> cast(attrs, [:nome, :email, :matricula, :telefone, :perfil])
    |> validar_campos()
  end

  @doc "Exclusão lógica (#8): o usuário é desativado, mas o histórico fica."
  def delete_changeset(usuario), do: change(usuario, ativo: false)

  defp validar_campos(changeset) do
    changeset
    |> update_change(:email, &normalizar_email/1)
    |> update_change(:matricula, &String.trim/1)
    |> validate_required([:nome, :email, :matricula, :perfil])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "não é um e-mail válido")
    |> unique_constraint(:email, message: "já está em uso por outro usuário")
    |> unique_constraint(:matricula, message: "já está em uso por outro usuário")
  end

  @doc "E-mails são comparados sem espaços nas pontas e em minúsculas."
  def normalizar_email(email), do: email |> String.trim() |> String.downcase()

  defp validar_senha(changeset) do
    changeset
    |> validate_required([:senha])
    |> validate_length(:senha, min: 8, max: 72)
    |> gerar_hash_da_senha()
  end

  defp gerar_hash_da_senha(%Ecto.Changeset{valid?: true, changes: %{senha: senha}} = changeset) do
    changeset
    |> put_change(:senha_hash, Pbkdf2.hash_pwd_salt(senha))
    |> delete_change(:senha)
  end

  defp gerar_hash_da_senha(changeset), do: changeset
end
