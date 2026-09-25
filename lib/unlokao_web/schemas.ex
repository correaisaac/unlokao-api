defmodule UnlokaoWeb.Schemas do
  @moduledoc """
  Schemas da documentação OpenAPI (#25). Descrevem o JSON que entra e sai da API;
  os testes em `test/unlokao_web/openapi_test.exs` conferem que as respostas
  reais batem com eles.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  defmodule Meta do
    OpenApiSpex.schema(%{
      title: "Meta",
      description: "Paginação da listagem",
      type: :object,
      properties: %{
        pagina: %Schema{type: :integer, example: 1},
        por_pagina: %Schema{type: :integer, example: 20},
        total: %Schema{type: :integer, example: 42},
        total_paginas: %Schema{type: :integer, example: 3}
      },
      required: [:pagina, :por_pagina, :total, :total_paginas]
    })
  end

  defmodule Erro do
    OpenApiSpex.schema(%{
      title: "Erro",
      description: """
      Erro de validação traz um objeto `{campo: [mensagens]}`; os demais erros
      trazem `{detail: mensagem}`.
      """,
      type: :object,
      properties: %{errors: %Schema{type: :object, additionalProperties: true}},
      required: [:errors],
      example: %{errors: %{codigo: ["já está em uso por outra chave"]}}
    })
  end

  # Chaves

  defmodule Chave do
    OpenApiSpex.schema(%{
      title: "Chave",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        codigo: %Schema{type: :string, example: "LAB-101-A"},
        espaco: %Schema{type: :string, example: "Laboratório 101"},
        bloco: %Schema{type: :string, nullable: true, example: "B"},
        descricao: %Schema{type: :string, nullable: true, example: "cópia principal"},
        status: %Schema{type: :string, enum: UnlokaoWeb.Schemas.Base.status_chave()},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :codigo, :espaco, :bloco, :descricao, :status, :inserted_at, :updated_at]
    })
  end

  defmodule ChaveEntrada do
    OpenApiSpex.schema(%{
      title: "ChaveEntrada",
      type: :object,
      properties: %{
        codigo: %Schema{type: :string, maxLength: 50, example: "LAB-101-A"},
        espaco: %Schema{type: :string, example: "Laboratório 101"},
        bloco: %Schema{type: :string, example: "B"},
        descricao: %Schema{type: :string, example: "cópia principal"}
      },
      required: [:codigo, :espaco]
    })
  end

  defmodule ChaveEdicao do
    OpenApiSpex.schema(%{
      title: "ChaveEdicao",
      description: "Só os campos enviados são alterados. `status` não aceita `emprestada`.",
      type: :object,
      properties: %{
        codigo: %Schema{type: :string, maxLength: 50},
        espaco: %Schema{type: :string},
        bloco: %Schema{type: :string},
        descricao: %Schema{type: :string},
        status: %Schema{type: :string, enum: ["disponivel", "indisponivel"]}
      }
    })
  end

  defmodule ChaveResposta do
    OpenApiSpex.schema(
      UnlokaoWeb.Schemas.Base.resposta("ChaveResposta", UnlokaoWeb.Schemas.Chave)
    )
  end

  defmodule ChaveLista do
    OpenApiSpex.schema(UnlokaoWeb.Schemas.Base.lista("ChaveLista", UnlokaoWeb.Schemas.Chave))
  end

  # Usuários

  defmodule Usuario do
    OpenApiSpex.schema(%{
      title: "Usuario",
      description: "A senha nunca é retornada.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        nome: %Schema{type: :string, example: "Maria Silva"},
        email: %Schema{type: :string, format: :email, example: "maria@universidade.edu.br"},
        matricula: %Schema{type: :string, example: "20231234"},
        telefone: %Schema{type: :string, nullable: true, example: "83 99999-0000"},
        perfil: %Schema{type: :string, enum: UnlokaoWeb.Schemas.Base.perfis()},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :nome, :email, :matricula, :telefone, :perfil, :inserted_at, :updated_at]
    })
  end

  defmodule UsuarioEntrada do
    OpenApiSpex.schema(%{
      title: "UsuarioEntrada",
      type: :object,
      properties: %{
        nome: %Schema{type: :string, example: "Maria Silva"},
        email: %Schema{type: :string, format: :email, example: "maria@universidade.edu.br"},
        matricula: %Schema{type: :string, example: "20231234"},
        telefone: %Schema{type: :string, example: "83 99999-0000"},
        perfil: %Schema{type: :string, enum: UnlokaoWeb.Schemas.Base.perfis()},
        senha: %Schema{type: :string, format: :password, minLength: 8, maxLength: 72}
      },
      required: [:nome, :email, :matricula, :perfil, :senha]
    })
  end

  defmodule UsuarioEdicao do
    OpenApiSpex.schema(%{
      title: "UsuarioEdicao",
      description: "Só os campos enviados são alterados. A senha não muda por aqui.",
      type: :object,
      properties: %{
        nome: %Schema{type: :string},
        email: %Schema{type: :string, format: :email},
        matricula: %Schema{type: :string},
        telefone: %Schema{type: :string},
        perfil: %Schema{type: :string, enum: UnlokaoWeb.Schemas.Base.perfis()}
      }
    })
  end

  defmodule UsuarioResposta do
    OpenApiSpex.schema(
      UnlokaoWeb.Schemas.Base.resposta("UsuarioResposta", UnlokaoWeb.Schemas.Usuario)
    )
  end

  defmodule UsuarioLista do
    OpenApiSpex.schema(UnlokaoWeb.Schemas.Base.lista("UsuarioLista", UnlokaoWeb.Schemas.Usuario))
  end

  # Autenticação

  defmodule LoginEntrada do
    OpenApiSpex.schema(%{
      title: "LoginEntrada",
      type: :object,
      properties: %{
        email: %Schema{type: :string, format: :email},
        senha: %Schema{type: :string, format: :password}
      },
      required: [:email, :senha]
    })
  end

  defmodule LoginResposta do
    OpenApiSpex.schema(
      UnlokaoWeb.Schemas.Base.resposta(
        "LoginResposta",
        %Schema{
          type: :object,
          properties: %{
            token: %Schema{
              type: :string,
              description: "Enviar em `Authorization: Bearer <token>`"
            },
            usuario: UnlokaoWeb.Schemas.Usuario
          },
          required: [:token, :usuario]
        }
      )
    )
  end

  defmodule TrocarSenhaEntrada do
    OpenApiSpex.schema(%{
      title: "TrocarSenhaEntrada",
      type: :object,
      properties: %{
        senha_atual: %Schema{type: :string, format: :password},
        senha: %Schema{type: :string, format: :password, minLength: 8, maxLength: 72}
      },
      required: [:senha_atual, :senha]
    })
  end

  defmodule EsqueciSenhaEntrada do
    OpenApiSpex.schema(%{
      title: "EsqueciSenhaEntrada",
      type: :object,
      properties: %{email: %Schema{type: :string, format: :email}},
      required: [:email]
    })
  end

  defmodule RedefinirSenhaEntrada do
    OpenApiSpex.schema(%{
      title: "RedefinirSenhaEntrada",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Token recebido no link do e-mail"},
        senha: %Schema{type: :string, format: :password, minLength: 8, maxLength: 72}
      },
      required: [:token, :senha]
    })
  end

  # Empréstimos

  defmodule Pessoa do
    OpenApiSpex.schema(%{
      title: "Pessoa",
      description: "Resumo de um usuário dentro de um empréstimo",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        nome: %Schema{type: :string},
        email: %Schema{type: :string, format: :email},
        matricula: %Schema{type: :string}
      },
      required: [:id, :nome, :email, :matricula]
    })
  end

  defmodule Emprestimo do
    OpenApiSpex.schema(%{
      title: "Emprestimo",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        chave: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            codigo: %Schema{type: :string},
            espaco: %Schema{type: :string},
            bloco: %Schema{type: :string, nullable: true}
          },
          required: [:id, :codigo, :espaco, :bloco]
        },
        usuario: UnlokaoWeb.Schemas.Pessoa,
        entregue_por: UnlokaoWeb.Schemas.Pessoa,
        recebido_por: %Schema{allOf: [UnlokaoWeb.Schemas.Pessoa], nullable: true},
        retirada_em: %Schema{type: :string, format: :"date-time"},
        prazo: %Schema{type: :string, format: :"date-time"},
        devolvida_em: %Schema{type: :string, format: :"date-time", nullable: true},
        atrasado: %Schema{type: :boolean, description: "Não devolvido e com o prazo vencido"},
        observacao: %Schema{type: :string, nullable: true}
      },
      required: [
        :id,
        :chave,
        :usuario,
        :entregue_por,
        :recebido_por,
        :retirada_em,
        :prazo,
        :devolvida_em,
        :atrasado,
        :observacao
      ]
    })
  end

  defmodule EmprestimoEntrada do
    OpenApiSpex.schema(%{
      title: "EmprestimoEntrada",
      type: :object,
      properties: %{
        chave_id: %Schema{type: :string, format: :uuid},
        usuario_id: %Schema{type: :string, format: :uuid},
        prazo: %Schema{
          type: :string,
          format: :"date-time",
          description: "Opcional; padrão de 4 horas depois da retirada"
        },
        observacao: %Schema{type: :string, maxLength: 255}
      },
      required: [:chave_id, :usuario_id]
    })
  end

  defmodule EmprestimoResposta do
    OpenApiSpex.schema(
      UnlokaoWeb.Schemas.Base.resposta("EmprestimoResposta", UnlokaoWeb.Schemas.Emprestimo)
    )
  end

  defmodule EmprestimoLista do
    OpenApiSpex.schema(
      UnlokaoWeb.Schemas.Base.lista("EmprestimoLista", UnlokaoWeb.Schemas.Emprestimo)
    )
  end

  defmodule Saude do
    OpenApiSpex.schema(%{
      title: "Saude",
      type: :object,
      properties: %{status: %Schema{type: :string, enum: ["ok"]}},
      required: [:status]
    })
  end
end
