defmodule Naive.SymbolSupervisor do
  @moduledoc """
  Supervise the trader Symbol
  """
  use Supervisor

  require Logger

  @registry :naive_symbol_supervisors

  def start_link(symbol) do
    Supervisor.start_link(__MODULE__, symbol, name: via_tuple(symbol))
  end

  def init(symbol) do
    Logger.info("Starting new supervision tree to trade on #{symbol}")

    Supervisor.init(
      [
        {
          DynamicSupervisor,
          strategy: :one_for_one, name: :"Naive.DynamicTraderSupervisor-#{symbol}"
        },
        {Naive.Leader, symbol}
      ],
      strategy: :one_for_all
    )
  end

  defp via_tuple(symbol) do
    {:via, Registry, {@registry, symbol}}
  end
end
