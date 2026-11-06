defmodule Unlokao.Repo.Migrations.CreateChaveAutorizacoes do
  use Ecto.Migration

  def change do
    alter table(:chaves) do
      add :restrita, :boolean, null: false, default: false
    end

    create table(:chave_autorizacoes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :chave_id, references(:chaves, type: :binary_id, on_delete: :restrict), null: false
      add :usuario_id, references(:usuarios, type: :binary_id, on_delete: :restrict), null: false
      add :autorizado_por_id, references(:usuarios, type: :binary_id, on_delete: :restrict)
      add :valida_ate, :date

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chave_autorizacoes, [:chave_id, :usuario_id])
    create index(:chave_autorizacoes, [:usuario_id])
  end
end
