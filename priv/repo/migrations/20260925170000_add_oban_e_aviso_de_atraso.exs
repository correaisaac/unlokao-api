defmodule Unlokao.Repo.Migrations.AddObanEAvisoDeAtraso do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 14)

    alter table(:emprestimos) do
      # Quando o usuário foi avisado do atraso; evita mandar o mesmo aviso de novo.
      add :atraso_avisado_em, :utc_datetime
    end
  end

  def down do
    alter table(:emprestimos) do
      remove :atraso_avisado_em
    end

    Oban.Migration.down(version: 1)
  end
end
