# unlokao-api

API do **Unlokao**, sistema de empréstimo das chaves físicas que dão acesso aos espaços da universidade.

Feita em [Elixir](https://elixir-lang.org) com [Phoenix](https://www.phoenixframework.org) e PostgreSQL.

**Documentação completa (Swagger):** `http://localhost:4000/api/docs` com a API rodando.
A especificação OpenAPI fica em `/api/openapi` e dá para gerar tipos para o front a partir dela.

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

Em dev os e-mails não são enviados: aparecem só no log do servidor.

## Endpoints

Todas as requisições e respostas são JSON. Os corpos são enviados sem envelope
(ex.: `{"codigo": "LAB-101-A", ...}`) e as respostas vêm dentro de `data`.

Faça login e envie o token recebido em todas as outras requisições:
`Authorization: Bearer <token>`. O token vale por 7 dias.

### Autenticação e minha conta

| Método | Rota | Acesso | Descrição |
|---|---|---|---|
| `POST` | `/api/login` | público | `{email, senha}` → `{token, usuario}` |
| `POST` | `/api/logout` | logado | Encerra a sessão atual |
| `GET` | `/api/me` | logado | Dados do usuário logado |
| `PUT` | `/api/me/senha` | logado | `{senha_atual, senha}`; encerra as outras sessões |
| `GET` | `/api/me/emprestimos` | logado | Empréstimos do usuário logado |
| `POST` | `/api/senha/esqueci` | público | `{email}`; envia link válido por 1 hora (responde `204` sempre) |
| `POST` | `/api/senha/redefinir` | público | `{token, senha}`; token de uso único, encerra todas as sessões |

### Chaves

| Método | Rota | Acesso | Descrição |
|---|---|---|---|
| `GET` | `/api/chaves` | logado | Lista; filtros `status`, `bloco`, `busca` |
| `GET` | `/api/chaves/:id` | logado | Detalha |
| `POST` | `/api/chaves` | admin | Cadastra (`codigo` e `espaco` obrigatórios) |
| `PATCH` | `/api/chaves/:id` | admin | Edita |
| `DELETE` | `/api/chaves/:id` | admin | Exclui (lógico); chave emprestada não pode |

`status`: `disponivel` \| `emprestada` \| `indisponivel`. Toda chave nasce `disponivel`,
e `emprestada` só muda pelo empréstimo e pela devolução.

### Usuários

| Método | Rota | Acesso | Descrição |
|---|---|---|---|
| `GET` | `/api/usuarios` | admin | Lista; filtros `perfil`, `busca` |
| `GET` | `/api/usuarios/:id` | admin | Detalha |
| `POST` | `/api/usuarios` | admin | Cadastra (`nome`, `email`, `matricula`, `perfil`, `senha`) |
| `PATCH` | `/api/usuarios/:id` | admin | Edita (a senha não muda por aqui) |
| `DELETE` | `/api/usuarios/:id` | admin | Desativa; não vale para si mesmo nem para quem está com chave |

`perfil`: `aluno` \| `professor` \| `servidor` \| `admin`. A senha é guardada com hash
(PBKDF2) e nunca aparece nas respostas.

### Empréstimos

| Método | Rota | Acesso | Descrição |
|---|---|---|---|
| `GET` | `/api/emprestimos` | admin | Lista; filtros `situacao` (`aberto`, `atrasado`, `devolvido`), `chave_id`, `usuario_id` |
| `GET` | `/api/emprestimos/:id` | admin | Detalha |
| `POST` | `/api/emprestimos` | admin | Retirada: `{chave_id, usuario_id, prazo?, observacao?}`; prazo padrão de 4 horas |
| `POST` | `/api/emprestimos/:id/devolucao` | admin | Devolução; a chave volta a ficar `disponivel` |

Uma chave nunca fica em dois empréstimos abertos, nem com retiradas simultâneas.
A cada 15 minutos, quem está atrasado recebe um aviso por e-mail (uma vez por empréstimo).

### Paginação

Toda listagem aceita `pagina` (padrão 1) e `por_pagina` (padrão 20, máx. 100) e responde
`{"data": [...], "meta": {"pagina", "por_pagina", "total", "total_paginas"}}`.

### Erros

| Status | Quando |
|---|---|
| `401` | Sem token, token inválido/expirado, ou e-mail/senha errados no login |
| `403` | Rota só para administradores |
| `404` | Registro não existe, foi excluído ou o id é inválido |
| `409` | Valor duplicado, chave indisponível, empréstimo já devolvido, exclusão bloqueada por empréstimo |
| `422` | Campo obrigatório ausente, valor ou filtro inválido, link de redefinição expirado |
| `429` | Muitas tentativas de login (10/min) ou de "esqueci minha senha" (5/hora) por IP |

Formato: `{"errors": {"campo": ["mensagem"]}}` ou `{"errors": {"detail": "mensagem"}}`.

## Deploy

A API roda em qualquer hospedagem que aceite Docker (Fly.io, Render, Railway, uma VM…).

```sh
docker build -t unlokao-api .
docker run --env-file .env -p 4000:4000 unlokao-api        # sobe a API
docker run --env-file .env unlokao-api bin/migrate         # roda as migrations (a cada deploy)
docker run --env-file .env -e ADMIN_EMAIL=... -e ADMIN_SENHA=... \
  unlokao-api bin/criar_admin                              # cria o primeiro admin (uma vez)
```

A hospedagem deve checar `GET /api/health`: responde 200 quando a API e o banco estão no ar.

### Variáveis de ambiente

| Variável | Obrigatória | Para quê |
|---|---|---|
| `DATABASE_URL` | sim | `ecto://usuario:senha@host/banco` |
| `SECRET_KEY_BASE` | sim | Gerar com `mix phx.gen.secret` |
| `PHX_HOST` | sim | Domínio público da API (ex.: `api.unlokao.app`) |
| `PORT` | não | Porta HTTP (padrão 4000) |
| `CORS_ORIGINS` | sim | Origens do front, separadas por vírgula (ex.: `https://unlokao.app`) |
| `URL_REDEFINIR_SENHA` | sim | Página do front que recebe `?token=...` no link de "esqueci minha senha" |
| `EMAIL_REMETENTE` | não | Endereço que envia os e-mails (padrão `nao-responda@unlokao.local`) |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USUARIO`, `SMTP_SENHA` | sim, para enviar e-mail | Servidor SMTP (587 com STARTTLS ou 465 com SSL). Sem `SMTP_HOST`, os e-mails só vão para o log |
| `POOL_SIZE` | não | Conexões com o banco (padrão 10) |

A API deve ficar atrás do proxy da hospedagem: o IP do cliente é lido do
`X-Forwarded-For` para o limite de tentativas.

## Onde está cada coisa

| Caminho | O quê |
|---|---|
| `lib/unlokao/chaves*`, `lib/unlokao/usuarios*` | Cadastro de chaves e usuários |
| `lib/unlokao/emprestimos*` | Empréstimo, devolução e aviso de atraso |
| `lib/unlokao/autenticacao*` | Login, sessões, troca e redefinição de senha |
| `lib/unlokao/paginacao.ex` | Filtros e paginação das listagens |
| `lib/unlokao_web/router.ex` | Rotas e quem pode acessar cada uma |
| `lib/unlokao_web/autenticacao.ex`, `lib/unlokao_web/limite_de_tentativas.ex` | Plugs de login/admin e de limite de tentativas |
| `lib/unlokao_web/controllers/` | Controllers HTTP, formato do JSON e documentação de cada rota |
| `lib/unlokao_web/schemas.ex` | Schemas da documentação OpenAPI |
| `priv/repo/migrations/` | Estrutura do banco |
| `priv/repo/seeds.exs` | Criação do primeiro admin |
| `test/` | Testes (um por critério de aceite das issues) |
