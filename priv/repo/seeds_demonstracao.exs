# Dados fictícios para desenvolver e apresentar o sistema: pessoas, chaves e listas de
# quem pode retirar cada chave restrita. Roda em `mix setup`, e só no ambiente de dev.
#
# Pode rodar mais de uma vez: o que já existir fica como está.

import Ecto.Query

alias Unlokao.{Chaves, Repo, Usuarios}
alias Unlokao.Chaves.{Autorizacao, Chave}
alias Unlokao.Usuarios.Usuario

# Pública no README: nunca usar estas contas fora do ambiente de desenvolvimento.
senha = "Unlokao@2026"

pessoas = [
  {:admin, "Renata Moura", "admin@unlokao.demo", "ADM-001", :admin},
  {:guarda, "Gilberto Souza", "guarda@unlokao.demo", "GRD-001", :guarda},
  {:helena, "Helena Prado", "helena.prado@unlokao.demo", "PROF-1001", :professor},
  {:marcos, "Marcos Lima", "marcos.lima@unlokao.demo", "PROF-1002", :professor},
  {:carla, "Carla Nunes", "carla.nunes@unlokao.demo", "SERV-2001", :servidor},
  {:ana, "Ana Beatriz Rocha", "ana.rocha@unlokao.demo", "20230001", :aluno},
  {:bruno, "Bruno Tavares", "bruno.tavares@unlokao.demo", "20230002", :aluno},
  {:diego, "Diego Alves", "diego.alves@unlokao.demo", "20230003", :aluno}
]

usuarios =
  Map.new(pessoas, fn {apelido, nome, email, matricula, perfil} ->
    usuario =
      Repo.get_by(Usuario, email: email) ||
        Usuarios.create_usuario(%{
          nome: nome,
          email: email,
          matricula: matricula,
          perfil: perfil,
          senha: senha
        })
        |> then(fn {:ok, usuario} -> usuario end)

    {apelido, usuario}
  end)

hoje = Date.utc_today()
fim_do_semestre = Date.add(hoje, 120)
semestre_passado = Date.add(hoje, -30)

# {código, espaço, bloco, descrição, lista}. Sem lista, a chave é livre.
chaves = [
  {"SALA-101", "Sala de Aula 101", "A", nil, nil},
  {"SALA-102", "Sala de Aula 102", "A", nil, nil},
  {"AUD-01", "Auditório Central", "A", "Chave principal", nil},
  {"LAB-101", "Laboratório de Redes", "B", "Equipamentos de rede",
   [helena: nil, carla: nil, ana: fim_do_semestre]},
  {"LAB-204", "Laboratório de Química", "C", "Armários com reagentes",
   [marcos: nil, bruno: semestre_passado]},
  {"ALM-01", "Almoxarifado", "A", "Material de consumo", [carla: nil]}
]

for {codigo, espaco, bloco, descricao, lista} <- chaves do
  chave =
    Repo.get_by(Chave, codigo: codigo) ||
      Chaves.create_chave(%{
        codigo: codigo,
        espaco: espaco,
        bloco: bloco,
        descricao: descricao,
        restrita: lista != nil
      })
      |> then(fn {:ok, chave} -> chave end)

  for {apelido, valida_ate} <- lista || [] do
    usuario_id = usuarios[apelido].id

    unless Repo.exists?(
             from a in Autorizacao,
               where: a.chave_id == ^chave.id and a.usuario_id == ^usuario_id
           ) do
      Repo.insert!(%Autorizacao{
        chave_id: chave.id,
        usuario_id: usuario_id,
        autorizado_por_id: usuarios.admin.id,
        valida_ate: valida_ate
      })
    end
  end
end

IO.puts("Seed: dados de demonstração prontos (veja o README para as contas).")
