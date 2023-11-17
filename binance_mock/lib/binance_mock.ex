defmodule BinanceMock do
  @moduledoc """
  Documentation for `BinanceMock`.
  """

  use GenServer

  alias Decimal
  alias Streamer.Binance.TradeEvent

  require Logger

  defmodule State do
    defstruct order_books: %{}, subscriptions: [], fake_order_id: 1
  end

  defmodule OrderBook do
    defstruct buy_side: [], sell_side: [], historical: []
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end


end
