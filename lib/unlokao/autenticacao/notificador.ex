defmodule Unlokao.Autenticacao.Notificador do
  @moduledoc "E-mails enviados pelo fluxo de autenticação."

  import Swoosh.Email

  alias Unlokao.Mailer

  def enviar_redefinicao_de_senha(usuario, url) do
    email =
      new()
      |> to({usuario.nome, usuario.email})
      |> from(Application.fetch_env!(:unlokao, :email_remetente))
      |> subject("Unlokao - redefinição de senha")
      |> text_body("""
      Olá, #{usuario.nome}!

      Recebemos um pedido para redefinir a sua senha no Unlokao.
      Para criar uma senha nova, acesse o link abaixo (válido por 1 hora):

      #{url}

      Se não foi você quem pediu, ignore este e-mail.
      """)

    with {:ok, _metadata} <- Mailer.deliver(email), do: {:ok, email}
  end
end
