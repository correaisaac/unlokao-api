defmodule Unlokao.Repo.Migrations.CreateUsuarios do
  use Ecto.Migration

  def change do
    create table(:usuarios, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :nome, :string, null: false
      add :email, :string, null: false
      add :matricula, :string, null: false
      add :telefone, :string
      add :perfil, :string, null: false
      add :senha_hash, :string, null: false
      add :ativo, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    # Únicos só entre usuários ativos, pelo mesmo motivo das chaves.
    create unique_index(:usuarios, [:email], where: "ativo")
    create unique_index(:usuarios, [:matricula], where: "ativo")
  end
end
