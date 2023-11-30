defmodule Naive.Leader do
  use GenServer

  alias Naive.Trader

  require Logger

  @binance_client Application.compile_env(:naive, :binance_client)

  defmodule State do
    defstruct symbol: nil,
              settings: nil,
              traders: []
  end

  defmodule TraderData do
    defstruct pid: nil,
              ref: nil,
              state: nil
  end

  def start_link(symbol) do
    GenServer.start_link(__MODULE__, symbol, name: :"#{__MODULE__}-#{symbol}")
  end

  def init(symbol) do
    {:ok, %State{symbol: symbol}, {:continue, :start_traders}}
  end

  def handle_continue(continue_arg, state) do

  end
end
