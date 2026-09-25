defmodule Unlokao.Limitador do
  @moduledoc """
  Contador de tentativas em memória (Hammer + ETS), usado para limitar login e
  "esqueci minha senha". Vale por instância: com várias instâncias da API, cada
  uma conta separado (trocar o backend para Redis se isso virar problema).
  """
  use Hammer, backend: :ets
end
