defmodule Unlokao.Emprestimos.Emprestimo do
  use Ecto.Schema
  import Ecto.Changeset

  alias Unlokao.Chaves.Chave
  alias Unlokao.Usuarios.Usuario

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "emprestimos" do
    belongs_to :chave, Chave
    belongs_to :usuario, Usuario
    belongs_to :entregue_por, Usuario
    belongs_to :recebido_por, Usuario

    field :retirada_em, :utc_datetime
    field :prazo, :utc_datetime
    field :devolvida_em, :utc_datetime
    field :observacao, :string
    field :atraso_avisado_em, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Retirada de uma chave (#18). Espera `retirada_em` e `entregue_por_id` já
  preenchidos no struct. Sem `prazo`, usa o prazo padrão configurado.
  """
  def retirada_changeset(emprestimo, attrs) do
    emprestimo
    |> cast(attrs, [:chave_id, :usuario_id, :prazo, :observacao])
    |> validate_required([:chave_id, :usuario_id])
    |> validar_uuid(:chave_id)
    |> validar_uuid(:usuario_id)
    |> validate_length(:observacao, max: 255)
    |> colocar_prazo_padrao()
    |> validate_change(:prazo, fn :prazo, prazo ->
      if DateTime.after?(prazo, emprestimo.retirada_em),
        do: [],
        else: [prazo: "deve ser depois do horário da retirada"]
    end)
    |> unique_constraint(:chave_id,
      name: :emprestimos_chave_aberta_index,
      message: "já está emprestada"
    )
  end

  @doc "Empréstimo não devolvido cujo prazo já passou."
  def atrasado?(emprestimo, agora \\ DateTime.utc_now())

  def atrasado?(%__MODULE__{devolvida_em: nil, prazo: prazo}, agora),
    do: DateTime.before?(prazo, agora)

  def atrasado?(%__MODULE__{}, _agora), do: false

  # `:binary_id` aceita qualquer texto no cast; sem isso um id malformado só
  # falharia na query (erro 500) em vez de virar erro de validação.
  defp validar_uuid(changeset, campo) do
    validate_change(changeset, campo, fn ^campo, valor ->
      if Ecto.UUID.cast(valor) == :error, do: [{campo, "is invalid"}], else: []
    end)
  end

  defp colocar_prazo_padrao(changeset) do
    if get_field(changeset, :prazo) do
      changeset
    else
      horas = Application.fetch_env!(:unlokao, :prazo_padrao_em_horas)

      put_change(
        changeset,
        :prazo,
        DateTime.add(get_field(changeset, :retirada_em), horas, :hour)
      )
    end
  end
end
