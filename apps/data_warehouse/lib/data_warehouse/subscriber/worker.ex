defmodule DataWarehouse.Subscriber.Worker do
  use GenServer

  require Logger

  defmodule State do
    @enforce_keys [:topic]
    defstruct [:topic]
  end

  def start_link(topic) do
    GenServer.start_link(__MODULE__, topic, name: :"#{__MODULE__}-#{topic}")
  end

  def init(topic) do
    Logger.info("DataWarehouse worker is subscribing to #{topic}")
    Phoenix.PubSub.subscribe(Streamer.PubSub, topic)
    {:ok, %State{topic: topic}}
  end

  def handle_info(%Streamer.Binance.TradeEvent{} = trade_event, state) do
    opts = trade_event |> Map.from_struct()

    struct!(DataWarehouse.Schema.TradeEvent, opts)
    |> DataWarehouse.Repo.insert()

    {:noreply, state}
  end
end
