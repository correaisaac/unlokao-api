# unlokao-api

API do **Unlokao**, sistema de empréstimo das chaves físicas que dão acesso aos espaços da universidade.

Feita em [Elixir](https://elixir-lang.org) com [Phoenix](https://www.phoenixframework.org) e PostgreSQL.

## Rodando localmente

Pré-requisitos: Elixir 1.18+ e Docker (para o Postgres).

```sh
docker compose up -d      # sobe o Postgres
mix setup                 # instala dependências, cria e migra o banco
mix phx.server            # API em http://localhost:4000/api
mix test                  # roda os testes
```

## Endpoints

Todas as requisições e respostas são JSON. Os corpos são enviados sem envelope
(ex.: `{"codigo": "LAB-101-A", ...}`) e as respostas vêm dentro de `data`.

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
| `404` | Registro não existe, foi excluído ou o id é inválido |
| `409` | Código/e-mail/matrícula já em uso, ou chave emprestada sendo excluída |
| `422` | Campo obrigatório ausente ou valor inválido |

Formato: `{"errors": {"campo": ["mensagem"]}}` ou `{"errors": {"detail": "mensagem"}}`.

## Onde está cada coisa

| Caminho | O quê |
|---|---|
| `lib/unlokao/chaves/chave.ex`, `lib/unlokao/usuarios/usuario.ex` | Schemas e validações |
| `lib/unlokao/chaves.ex`, `lib/unlokao/usuarios.ex` | Regras de negócio (contexts) |
| `lib/unlokao_web/controllers/` | Controllers HTTP e formato do JSON |
| `lib/unlokao_web/controllers/fallback_controller.ex` | Mapeamento de erros para status HTTP |
| `priv/repo/migrations/` | Estrutura do banco |
| `test/` | Testes (um por critério de aceite das issues) |
