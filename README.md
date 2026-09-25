# unlokao-api

API do **Unlokao**, sistema de empréstimo das chaves físicas que dão acesso aos espaços da universidade.

Feita em [Elixir](https://elixir-lang.org) com [Phoenix](https://www.phoenixframework.org) e PostgreSQL.

## Rodando localmente

Pré-requisitos: Elixir 1.18+ e Docker (para o Postgres).

```sh
docker compose up -d      # sobe o Postgres
ADMIN_EMAIL=admin@universidade.edu.br ADMIN_SENHA=uma-senha-forte \
  mix setup               # instala dependências, cria e migra o banco e cria o primeiro admin
mix phx.server            # API em http://localhost:4000/api
mix test                  # roda os testes
```

O primeiro admin também pode ser criado depois, com
`ADMIN_EMAIL=... ADMIN_SENHA=... mix run priv/repo/seeds.exs` (rodar de novo não duplica).

### Variáveis de ambiente (produção)

| Variável | Para quê |
|---|---|
| `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST` | Padrão do Phoenix |
| `URL_REDEFINIR_SENHA` | Página do front que recebe `?token=...` no link de "esqueci minha senha" |

Em dev os e-mails não são enviados: aparecem só no log do servidor.

## Endpoints

Todas as requisições e respostas são JSON. Os corpos são enviados sem envelope
(ex.: `{"codigo": "LAB-101-A", ...}`) e as respostas vêm dentro de `data`.

### Autenticação — [#10](https://github.com/correaisaac/unlokao-api/issues/10)

Faça login e envie o token recebido em todas as outras requisições:
`Authorization: Bearer <token>`. O token vale por 7 dias.

| Método | Rota | Acesso | Descrição |
|---|---|---|---|
| `POST` | `/api/login` | público | `{email, senha}` → `{token, usuario}` |
| `POST` | `/api/logout` | logado | Encerra a sessão atual |
| `GET` | `/api/me` | logado | Dados do usuário logado |
| `PUT` | `/api/me/senha` | logado | `{senha_atual, senha}`; encerra as outras sessões |
| `POST` | `/api/senha/esqueci` | público | `{email}`; envia link válido por 1 hora (responde `204` sempre) |
| `POST` | `/api/senha/redefinir` | público | `{token, senha}`; token de uso único, encerra todas as sessões |

**Permissões:** qualquer usuário logado lista e consulta chaves; criar, editar e
excluir chaves e tudo em `/api/usuarios` é só para `admin`.

### Chaves — [#1](https://github.com/correaisaac/unlokao-api/issues/1)

| Método | Rota | Descrição |
|---|---|---|
| `GET` | `/api/chaves` | Lista as chaves ativas |
| `GET` | `/api/chaves/:id` | Detalha uma chave |
| `POST` | `/api/chaves` | Cadastra (`codigo` e `espaco` obrigatórios; `bloco`, `descricao` opcionais) |
| `PATCH` | `/api/chaves/:id` | Edita `codigo`, `espaco`, `bloco`, `descricao`, `status` |
| `DELETE` | `/api/chaves/:id` | Exclui (lógico) |

`status`: `disponivel` \| `emprestada` \| `indisponivel`. Toda chave nasce `disponivel`,
e `emprestada` só muda pelo fluxo de empréstimo/devolução.

### Usuários — [#5](https://github.com/correaisaac/unlokao-api/issues/5)

| Método | Rota | Descrição |
|---|---|---|
| `GET` | `/api/usuarios` | Lista os usuários ativos |
| `GET` | `/api/usuarios/:id` | Detalha um usuário |
| `POST` | `/api/usuarios` | Cadastra (`nome`, `email`, `matricula`, `perfil`, `senha` obrigatórios; `telefone` opcional) |
| `PATCH` | `/api/usuarios/:id` | Edita `nome`, `email`, `matricula`, `telefone`, `perfil` |
| `DELETE` | `/api/usuarios/:id` | Desativa (lógico) |

`perfil`: `aluno` \| `professor` \| `servidor` \| `admin`. A senha é guardada com hash
(PBKDF2) e nunca aparece nas respostas.

### Erros

| Status | Quando |
|---|---|
| `401` | Sem token, token inválido/expirado, ou e-mail/senha errados no login |
| `403` | Rota só para administradores |
| `404` | Registro não existe, foi excluído ou o id é inválido |
| `409` | Código/e-mail/matrícula já em uso, ou chave emprestada sendo excluída |
| `422` | Campo obrigatório ausente, valor inválido, admin excluindo a si mesmo ou link de redefinição expirado |

Formato: `{"errors": {"campo": ["mensagem"]}}` ou `{"errors": {"detail": "mensagem"}}`.

## Onde está cada coisa

| Caminho | O quê |
|---|---|
| `lib/unlokao/chaves/chave.ex`, `lib/unlokao/usuarios/usuario.ex` | Schemas e validações |
| `lib/unlokao/chaves.ex`, `lib/unlokao/usuarios.ex` | Regras de negócio (contexts) |
| `lib/unlokao/autenticacao.ex`, `lib/unlokao/autenticacao/` | Login, sessões, troca e redefinição de senha |
| `lib/unlokao_web/autenticacao.ex` | Plugs que exigem login/admin (usados no router) |
| `lib/unlokao_web/router.ex` | Rotas e quem pode acessar cada uma |
| `lib/unlokao_web/controllers/` | Controllers HTTP e formato do JSON |
| `lib/unlokao_web/controllers/fallback_controller.ex` | Mapeamento de erros para status HTTP |
| `priv/repo/migrations/` | Estrutura do banco |
| `priv/repo/seeds.exs` | Criação do primeiro admin |
| `test/` | Testes (um por critério de aceite das issues) |
