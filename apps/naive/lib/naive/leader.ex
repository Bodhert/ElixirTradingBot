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

  def handle_continue(:start_traders, %{symbol: symbol} = state) do
    settings = fetch_symbol_settings(symbol)
    trader_state = fresh_trader_state(settings)
    trader = for _i <- 1..settings.chunks, do: start_new_trader(trader_state)

    {:noreply, %{state | settings: settings, traders: traders}}
  end

  defp fresh_trader_state(settings) do
    struct(Trader.State, settings)
  end

  defp fetch_symbol_settings(symbol) do
    tick_size = fetch_tick_size(symbol)

    %{
      symbol: symbol,
      chunks: 1,
      profit_interval: "-0.0012",
      tick_size: tick_size
    }
  end

  defp fetch_tick_size(symbol) do
    @binance_client.get_exchange_info()
    |> elem(1)
    |> Map.get(:symbols)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> Map.get("filters")
    |> Enum.find(&(&1["filterType"] == "PRICE_FILTER"))
    |> Map.get("tickSize")
  end

  defp start_new_trader(%Trader.State{} = state) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        :"Naive.DynamicTraderSupervisor-#{state.symbol}",
        {Naive.Trader, state}
      )

      ref = Process.monitor(pid)

      %TraderData{pid: pid, ref: ref, state: state}
  end
end
