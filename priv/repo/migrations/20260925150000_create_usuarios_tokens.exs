defmodule Unlokao.Repo.Migrations.CreateUsuariosTokens do
  use Ecto.Migration

  def change do
    create table(:usuarios_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :usuario_id, references(:usuarios, type: :binary_id, on_delete: :delete_all),
        null: false

      # Só o hash SHA-256 do token fica no banco; o token em si vai apenas para o cliente.
      add :token, :binary, null: false
      add :contexto, :string, null: false
      add :enviado_para, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:usuarios_tokens, [:usuario_id])
    create unique_index(:usuarios_tokens, [:contexto, :token])
  end
end
