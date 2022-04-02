defmodule BinanceMock do
  use GenServer

  alias Decimal, as: D

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

  def get_exchange_info do
    Binance.get_exchange_info()
  end

  def order_limit_buy(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "BUY")
  end

  def order_limit_sell(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "SELL")
  end

  defp order_limit(symbol, quantity, price, side) do
    %Binance.Order{} =
      fake_order =
      generate_fake_order(
        symbol,
        quantity,
        price,
        side
      )

    GenServer.cast(
      __MODULE__,
      {:add_order, fake_order}
    )

    {:ok, convert_order_to_order_response(fake_order)}
  end

  def handle_cast(
        {:add_order, %Binance.Order{symbol: symbol} = order},
        %State{
          order_books: order_books,
          subscriptions: subscriptions
        } = state
      ) do
    new_subscriptions = subscribe_to_topic(symbol, subscriptions)
    updated_order_books = add_order(order, order_books)

    {
      :noreply,
      %{state | order_books: updated_order_books, subscriptions: new_subscriptions}
    }
  end

  defp subscribe_to_topic(symbol, subscriptions) do
    symbol = String.upcase(symbol)
    stream_name = "TRADE_EVENTS:#{symbol}"

    case Enum.member?(subscriptions, symbol) do
      false ->
        Logger.debug("BinaceMock subscribing to #{stream_name}")

        Phoenix.PubSub.subscribe(Streamer.PubSub, stream_name)
        [symbol | subscriptions]

      _ ->
        subscriptions
    end
  end

  defp add_order(%Binance.Order{symbol: symbol} = order, order_books) do
    order_book = Map.get(order_books, :"#{symbol}", %OrderBook{})

    # TODO analice this piece of code
    order_book =
      if(order.side == "SELL") do
        Map.replace!(
          order_book,
          :sell_side,
          # TODO analize this piece when runing the code
          [order | order_book] |> Enum.sort(fn first, second -> D.gt?(first, second) end)
        )
      else
        Map.replace!(
          order_book,
          :buy_side,
          [order | order_book] |> Enum.sort(fn first, second -> D.gt?(first, second) end)
        )
      end

    Map.put(order_books, :"#{symbol}", order_book)
  end
end
