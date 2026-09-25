defmodule Unlokao.Emprestimos.Notificador do
  @moduledoc "E-mails sobre empréstimos."

  import Swoosh.Email

  alias Unlokao.Mailer

  def enviar_aviso_de_atraso(emprestimo) do
    %{usuario: usuario, chave: chave} = emprestimo

    email =
      new()
      |> to({usuario.nome, usuario.email})
      |> from(Application.fetch_env!(:unlokao, :email_remetente))
      |> subject("Unlokao - devolução da chave #{chave.codigo} atrasada")
      |> text_body("""
      Olá, #{usuario.nome}!

      O prazo para devolver a chave #{chave.codigo} (#{chave.espaco}) terminou em
      #{Calendar.strftime(emprestimo.prazo, "%d/%m/%Y às %H:%M")} (UTC).

      Por favor, devolva a chave o quanto antes na portaria.
      """)

    with {:ok, _metadata} <- Mailer.deliver(email), do: {:ok, email}
  end
end
