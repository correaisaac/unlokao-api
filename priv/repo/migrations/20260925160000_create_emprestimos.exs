defmodule Unlokao.Repo.Migrations.CreateEmprestimos do
  use Ecto.Migration

  def change do
    create table(:emprestimos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :chave_id, references(:chaves, type: :binary_id, on_delete: :restrict), null: false
      add :usuario_id, references(:usuarios, type: :binary_id, on_delete: :restrict), null: false

      add :entregue_por_id, references(:usuarios, type: :binary_id, on_delete: :restrict),
        null: false

      add :recebido_por_id, references(:usuarios, type: :binary_id, on_delete: :restrict)
      add :retirada_em, :utc_datetime, null: false
      add :prazo, :utc_datetime, null: false
      add :devolvida_em, :utc_datetime
      add :observacao, :string

      timestamps(type: :utc_datetime)
    end

    # Garantia no banco: uma chave só pode estar em um empréstimo aberto por vez.
    create unique_index(:emprestimos, [:chave_id],
             where: "devolvida_em IS NULL",
             name: :emprestimos_chave_aberta_index
           )

    create index(:emprestimos, [:usuario_id])
    create index(:emprestimos, [:retirada_em])
  end
end
