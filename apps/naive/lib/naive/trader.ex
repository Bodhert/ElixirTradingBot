defmodule Naive.Trader do
  @moduledoc """
  Trader implementation
  """

  use GenServer, restart: :temporary

  require Logger

  alias Streamer.Binance.TradeEvent

  @binance_client Application.compile_env(:naive, :binance_client)
  defmodule State do
    @moduledoc """
    Trader State
    """
    @enforce_keys [:symbol, :budget, :buy_down_interval, :profit_interval, :tick_size, :step_size]
    defstruct [
      :symbol,
      :budget,
      :buy_order,
      :sell_order,
      :buy_down_interval,
      :profit_interval,
      :tick_size,
      :step_size
    ]
  end

  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%State{symbol: symbol} = state) do
    symbol = String.upcase(symbol)

    Logger.info("Initializing new trader for symbol(#{symbol})")

    Phoenix.PubSub.subscribe(Streamer.PubSub, "TRADE_EVENTS:#{symbol}")

    {:ok, state}
  end

  def handle_info(
        %TradeEvent{price: price},
        %State{
          symbol: symbol,
          budget: budget,
          buy_order: nil,
          buy_down_interval: buy_down_interval,
          tick_size: tick_size,
          step_size: step_size
        } = state
      ) do
    price = calculate_buy_price(price, buy_down_interval, tick_size)
    quantity = calculate_quantity(budget, price, step_size)

    Logger.info("Placing BUY order for #{symbol} @ #{price}, quantity: #{quantity}")

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    new_state = %{state | buy_order: order}
    Naive.Leader.notify(:trader_state_updated, new_state)

    {:noreply, new_state}
  end

  def handle_info(
        %TradeEvent{buyer_order_id: order_id},
        %State{
          symbol: symbol,
          buy_order:
            %Binance.OrderResponse{
              price: buy_price,
              order_id: order_id,
              orig_qty: quantity,
              transac_time: timestamp
            } = buy_order,
          profit_interval: profit_interval,
          tick_size: tick_size
        } = state
      ) do
    {:ok, %Binance.Order{} = current_buy_order} =
      @binance_client.get_order(symbol, timestamp, order_id)

    buy_order = %{buy_order | status: current_buy_order.status}

    {:ok, new_state} =
      if buy_order.status == "FILLED" do
        sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

        Logger.info(
          "Buy order filled, placing SELL order for " <>
            "#{symbol} @ #{sell_price}, quantity: #{quantity}"
        )

        {:ok, %Binance.OrderResponse{} = order} =
          @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

        {:ok, %{state | buy_order: buy_order, sell_order: order}}
      else
        Logger.info("Buy order partially filled")

        {:ok, %{state | buy_order: buy_order}}
      end

    Naive.Leader.notify(:trader_state_updated, new_state)

    {:noreply, new_state}
  end

  def handle_info(
        %TradeEvent{
          seller_order_id: order_id,
          quantity: quantity
        },
        %State{sell_order: %Binance.OrderResponse{order_id: order_id, orig_qty: quantity}} = state
      ) do
    Logger.info("Trade finished, trader will now exit")
    {:stop, :normal, state}
  end

  def handle_info(%TradeEvent{}, state) do
    {:noreply, state}
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    fee = "1.001"
    original_price = Decimal.mult(buy_price, fee)

    net_target_price = Decimal.mult(original_price, Decimal.add("1.0", profit_interval))

    gross_target_price = Decimal.mult(net_target_price, fee)

    Decimal.to_string(
      Decimal.mult(
        Decimal.div_int(gross_target_price, tick_size),
        tick_size
      ),
      :normal
    )
  end

  defp calculate_buy_price(current_price, buy_down_interval, tick_size) do
    exact_buy_price = Decimal.sub(current_price, Decimal.mult(current_price, buy_down_interval))

    Decimal.to_string(
      Decimal.mult(Decimal.div_int(exact_buy_price, tick_size), tick_size),
      :normal
    )
  end

  defp calculate_quantity(budget, price, step_size) do
    exact_target_quantity = Decimal.div(budget, price)

    Decimal.to_string(
      Decimal.mult(Decimal.div_int(exact_target_quantity, step_size), step_size),
      :normal
    )
  end
end
