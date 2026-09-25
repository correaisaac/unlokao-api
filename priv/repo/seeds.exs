# Cria o primeiro administrador (#15), já que só admins cadastram usuários.
#
#     ADMIN_EMAIL=admin@universidade.edu.br ADMIN_SENHA=uma-senha-forte mix run priv/repo/seeds.exs
#
# Pode rodar mais de uma vez: se o admin já existir, nada muda.

alias Unlokao.{Repo, Usuarios}
alias Unlokao.Usuarios.Usuario

email = System.get_env("ADMIN_EMAIL")
senha = System.get_env("ADMIN_SENHA")

cond do
  is_nil(email) or is_nil(senha) ->
    IO.puts("Seed: defina ADMIN_EMAIL e ADMIN_SENHA para criar o primeiro admin.")

  Repo.get_by(Usuario, email: Usuario.normalizar_email(email), ativo: true) ->
    IO.puts("Seed: o usuário #{email} já existe, nada a fazer.")

  true ->
    attrs = %{
      nome: "Administrador",
      email: email,
      matricula: "admin",
      perfil: :admin,
      senha: senha
    }

    case Usuarios.create_usuario(attrs) do
      {:ok, admin} ->
        IO.puts("Seed: admin #{admin.email} criado.")

      {:error, changeset} ->
        erros = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        raise "Seed: não foi possível criar o admin: #{inspect(erros)}"
    end
end
