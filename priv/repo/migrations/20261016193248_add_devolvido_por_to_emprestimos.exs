defmodule Unlokao.Repo.Migrations.AddDevolvidoPorToEmprestimos do
  use Ecto.Migration

  def change do
    alter table(:emprestimos) do
      # Quem devolveu a chave fisicamente (pode ser diferente de quem retirou, #recebido_por
      # continua sendo o guarda/admin que processou a devolução). Opcional: a devolução pela
      # etiqueta da chave, sem o leitor em 2 passos, não identifica quem está devolvendo.
      add :devolvido_por_id, references(:usuarios, type: :binary_id, on_delete: :restrict)
    end

    create index(:emprestimos, [:devolvido_por_id])
  end
end
