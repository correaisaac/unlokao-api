defmodule Unlokao.Chaves.Autorizacao do
  @moduledoc "Uma linha da lista de quem pode retirar uma chave restrita."
  use Ecto.Schema
  import Ecto.Changeset

  alias Unlokao.Chaves.Chave
  alias Unlokao.Usuarios.Usuario

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chave_autorizacoes" do
    belongs_to :chave, Chave
    belongs_to :usuario, Usuario
    belongs_to :autorizado_por, Usuario

    # Último dia em que a autorização vale; sem data, vale até ser removida.
    field :valida_ate, :date

    timestamps(type: :utc_datetime)
  end

  @doc "Espera `chave_id` e `autorizado_por_id` já preenchidos no struct."
  def changeset(autorizacao, attrs) do
    autorizacao
    |> cast(attrs, [:usuario_id, :valida_ate])
    |> validate_required([:usuario_id])
    |> validate_change(:usuario_id, fn :usuario_id, valor ->
      if Ecto.UUID.cast(valor) == :error, do: [usuario_id: "is invalid"], else: []
    end)
    |> unique_constraint(:usuario_id,
      name: :chave_autorizacoes_chave_id_usuario_id_index,
      message: "já está na lista desta chave"
    )
  end

  @doc "A autorização ainda vale?"
  def vigente?(%__MODULE__{valida_ate: nil}), do: true

  def vigente?(%__MODULE__{valida_ate: valida_ate}),
    do: Date.compare(valida_ate, Date.utc_today()) != :lt
end
