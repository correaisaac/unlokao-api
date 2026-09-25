defmodule Unlokao.Emprestimos.AvisarAtrasos do
  @moduledoc """
  Job do Oban que avisa por e-mail quem está atrasado (#22).
  Roda a cada 15 minutos (ver `config :unlokao, Oban` em `config/config.exs`).
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {:ok, _avisados} = Unlokao.Emprestimos.avisar_atrasos()
    :ok
  end
end
