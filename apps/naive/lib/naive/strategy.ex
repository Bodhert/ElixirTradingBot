defmodule Naive.Strategy do
  @moduledoc """
  Module in charge of making and executing descicions
  """
  alias Core.Struct.TradeEvent
  alias Naive.Trader.State

  require Logger

  @binance_client Application.compile_env(:naive, :binance_client)
  @leader Application.compile_env(:naive, :leader)
  @logger Application.compile_env(:core, :logger)
  @pubsub_client Application.compile_env(:core, :pubsub_client)

  def execute(%TradeEvent{} = trade_event, %State{} = state) do
    generate_decision(trade_event, state)
    |> execute_decision(state)
  end

  def generate_decision(
        %TradeEvent{price: price},
        %State{
          budget: budget,
          buy_order: nil,
          buy_down_interval: buy_down_interval,
          tick_size: tick_size,
          step_size: step_size
        }
      ) do
    price = calculate_buy_price(price, buy_down_interval, tick_size)
    quantity = calculate_quantity(budget, price, step_size)

    {:place_buy_order, price, quantity}
  end

  def generate_decision(
        %TradeEvent{buyer_order_id: order_id},
        %State{
          buy_order: %Binance.OrderResponse{
            order_id: order_id,
            status: "FILLED"
          },
          sell_order: %Binance.OrderResponse{}
        }
      )
      when is_number(order_id) do
    :skip
  end

  def generate_decision(
        %TradeEvent{buyer_order_id: order_id},
        %State{
          buy_order: %Binance.OrderResponse{
            order_id: order_id
          },
          sell_order: nil
        }
      )
      when is_number(order_id) do
    :fetch_buy_order
  end

  def generate_decision(
        %TradeEvent{},
        %State{
          buy_order: %Binance.OrderResponse{
            status: "FILLED",
            price: buy_price
          },
          sell_order: nil,
          profit_interval: profit_interval,
          tick_size: tick_size
        }
      ) do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    {:place_sell_order, sell_price}
  end

  def generate_decision(
        %TradeEvent{},
        %State{
          sell_order: %Binance.OrderResponse{status: "FILLED"}
        }
      ) do
    :exit
  end

  def generate_decision(
        %TradeEvent{
          seller_order_id: order_id
        },
        %State{
          sell_order: %Binance.OrderResponse{
            order_id: order_id
          }
        }
      ) do
    :fetch_sell_order
  end

  def generate_decision(
        %TradeEvent{price: current_price},
        %State{
          buy_order: %Binance.OrderResponse{price: buy_price},
          rebuy_interval: rebuy_interval,
          rebuy_notified: false
        }
      ) do
    if trigger_rebuy?(buy_price, current_price, rebuy_interval) do
      :rebuy
    else
      :skip
    end
  end

  def generate_decision(%TradeEvent{}, _state) do
    :skip
  end

  def calculate_sell_price(buy_price, profit_interval, tick_size) do
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

  def calculate_buy_price(current_price, buy_down_interval, tick_size) do
    exact_buy_price = Decimal.sub(current_price, Decimal.mult(current_price, buy_down_interval))

    Decimal.to_string(
      Decimal.mult(Decimal.div_int(exact_buy_price, tick_size), tick_size),
      :normal
    )
  end

  def calculate_quantity(budget, price, step_size) do
    exact_target_quantity = Decimal.div(budget, price)

    Decimal.to_string(
      Decimal.mult(Decimal.div_int(exact_target_quantity, step_size), step_size),
      :normal
    )
  end

  def trigger_rebuy?(buy_price, current_price, rebuy_interval) do
    rebuy_price =
      Decimal.sub(buy_price, Decimal.mult(buy_price, rebuy_interval))

    Decimal.lt?(current_price, rebuy_price)
  end

  defp execute_decision(
         {:place_buy_order, price, quantity},
         %State{
           id: id,
           symbol: symbol
         } = state
       ) do
    @logger.info(
      "The trader(#{id}) is placing a BUY order " <>
        "for #{symbol} @ #{price}, quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    :ok = broadcast_order(order)

    new_state = %{state | buy_order: order}
    @leader.notify(:trader_state_updated, new_state)

    {:ok, new_state}
  end

  defp execute_decision(
         {:place_sell_order, sell_price},
         %State{
           id: id,
           symbol: symbol,
           buy_order: %Binance.OrderResponse{
             orig_qty: quantity
           }
         } = state
       ) do
    @logger.info(
      "The trader(#{id}) is placing a SELL order for " <>
        "#{symbol} @ #{sell_price}, quantity: #{quantity}."
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

    :ok = broadcast_order(order)

    new_state = %{state | sell_order: order}

    @leader.notify(:trader_state_updated, new_state)

    {:ok, new_state}
  end

  defp execute_decision(
         :fetch_buy_order,
         %State{
           id: id,
           symbol: symbol,
           buy_order:
             %Binance.OrderResponse{
               order_id: order_id,
               transact_time: timestamp
             } = buy_order
         } = state
       ) do
    @logger.info("Trader's(#{id} #{symbol} buy order got partially filled")

    {:ok, %Binance.Order{} = current_buy_order} =
      @binance_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_buy_order)

    buy_order = %{buy_order | status: current_buy_order.status}
    new_state = %{state | buy_order: buy_order}

    @leader.notify(:trader_state_updated, new_state)

    {:ok, new_state}
  end

  defp execute_decision(
         :exit,
         %State{
           id: id,
           symbol: symbol
         }
       ) do
    @logger.info("Trader(#{id}) finished trade cycle for #{symbol}")
    :exit
  end

  defp execute_decision(
         :fetch_sell_order,
         %State{
           id: id,
           symbol: symbol,
           sell_order:
             %Binance.OrderResponse{
               order_id: order_id,
               transact_time: timestamp
             } = sell_order
         } = state
       ) do
    @logger.info("Trader's(#{id} #{symbol} SELL order got partially filled")

    {:ok, %Binance.Order{} = current_sell_order} =
      @binance_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_sell_order)

    new_state = %{state | sell_order: sell_order}
    @leader.notify(:trader_state_updated, new_state)
    {:ok, new_state}
  end

  defp execute_decision(
         :rebuy,
         %State{
           id: id,
           symbol: symbol
         } = state
       ) do
    @logger.info("Rebuy triggered for #{symbol} by the trader(#{id})")
    new_state = %{state | rebuy_notified: true}
    @leader.notify(:rebuy_triggered, new_state)
    {:ok, new_state}
  end

  defp execute_decision(:skip, state) do
    {:ok, state}
  end

  defp broadcast_order(%Binance.OrderResponse{} = response) do
    response
    |> convert_to_order
    |> broadcast_order
  end

  defp broadcast_order(%Binance.Order{} = order) do
    @pubsub_client.broadcast(Core.PubSub, "ORDERS:#{order.symbol}", order)
  end

  defp convert_to_order(%Binance.OrderResponse{} = response) do
    data = response |> Map.from_struct()

    Binance.Order
    |> struct(data)
    |> Map.merge(%{
      cummulative_quote_qty: "0.00000000",
      stop_price: "0.00000000",
      iceberg_qty: "0.00000000",
      is_working: true
    })
  end
end
