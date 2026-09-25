defmodule Unlokao.Chaves.Chave do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chaves" do
    field :codigo, :string
    field :espaco, :string
    field :bloco, :string
    field :descricao, :string

    field :status, Ecto.Enum,
      values: [:disponivel, :emprestada, :indisponivel],
      default: :disponivel

    field :ativo, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc "Cadastro de uma chave nova (#2). Toda chave nasce `disponivel`."
  def create_changeset(chave, attrs) do
    chave
    |> cast(attrs, [:codigo, :espaco, :bloco, :descricao])
    |> validar_campos()
  end

  @doc "Edição de uma chave (#3)."
  def update_changeset(chave, attrs) do
    chave
    |> cast(attrs, [:codigo, :espaco, :bloco, :descricao, :status])
    |> validar_campos()
    |> validar_mudanca_de_status()
  end

  @doc "Exclusão lógica (#4): a chave some das listagens, mas o histórico fica."
  def delete_changeset(chave), do: change(chave, ativo: false)

  defp validar_campos(changeset) do
    changeset
    |> update_change(:codigo, &String.trim/1)
    |> validate_required([:codigo, :espaco])
    |> validate_length(:codigo, max: 50)
    |> unique_constraint(:codigo, message: "já está em uso por outra chave")
  end

  # `emprestada` é controlado pelo fluxo de empréstimo/devolução, nunca à mão.
  defp validar_mudanca_de_status(changeset) do
    case {changeset.data.status, get_change(changeset, :status)} do
      {_, nil} ->
        changeset

      {:emprestada, _} ->
        add_error(changeset, :status, "chave emprestada só muda de status pela devolução")

      {_, :emprestada} ->
        add_error(changeset, :status, "chave só fica emprestada pelo registro de empréstimo")

      _ ->
        changeset
    end
  end
end
