defmodule Indicator.Ohlc.Worker do
  use GenServer
  require Logger
  alias Core.Struct.TradeEvent

  @logger Application.compile_env(:core, :logger)
  @pubsub_client Application.compile_env(:core, :pubsub_client)

  def start_link({symbol, duration}) do
    GenServer.start_link(__MODULE__, {symbol, duration})
  end

  def init({symbol, duration}) do
    symbol = String.upcase(symbol)
    Logger.info("Initializing a new OHLC worker (#{duration} minutes) for #{symbol}")

    @pubsub_client.subscribe(
      Core.PubSub,
      "TRADE_EVENTS:#{symbol}"
    )

    {:ok, {symbol, duration}}
  end

  def handle_info(%TradeEvent{} = trade_event, ohlc) do
    {:noreply, Indicator.Ohlc.process(ohlc, trade_event)}
  end
end
