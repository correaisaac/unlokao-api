defmodule Unlokao.Repo.Migrations.CreateChaves do
  use Ecto.Migration

  def change do
    create table(:chaves, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codigo, :string, null: false
      add :espaco, :string, null: false
      add :bloco, :string
      add :descricao, :string
      add :status, :string, null: false, default: "disponivel"
      add :ativo, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    # Único só entre chaves ativas: uma chave excluída libera o código para reuso.
    create unique_index(:chaves, [:codigo], where: "ativo")
  end
end
