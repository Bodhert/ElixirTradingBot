defmodule Naive.Strategy do
  @moduledoc """
  Module in charge of making and executing decisions
  """
  alias Core.Struct.TradeEvent
  alias Naive.Repo
  alias Naive.Schema.Settings

  require Logger

  @binance_client Application.compile_env(:naive, :binance_client)

  defmodule Position do
    @enforce_keys [
      :id,
      :symbol,
      :budget,
      :buy_down_interval,
      :profit_interval,
      :rebuy_interval,
      :rebuy_notified,
      :tick_size,
      :step_size
    ]
    defstruct [
      :id,
      :symbol,
      :budget,
      :buy_order,
      :sell_order,
      :buy_down_interval,
      :profit_interval,
      :rebuy_interval,
      :rebuy_notified,
      :tick_size,
      :step_size
    ]
  end

  def execute(%TradeEvent{} = trade_event, positions, settings) do
    generate_decisions(positions, [], trade_event, settings)
    |> Enum.map(fn {decision, position} ->
      Task.async(fn -> execute_decision(decision, position, settings) end)
    end)
    |> Task.await_many()
    |> then(&parse_results/1)
  end

  def parse_results([]), do: :exit

  def parse_results([_ | _] = results) do
    results
    |> Enum.map(fn {:ok, new_position} -> new_position end)
    |> then(&{:ok, &1})
  end

  def generate_decisions([], generated_results, _trade_event, _settings) do
    generated_results
  end

  def generate_decisions([position | rest] = positions, generated_results, trade_event, settings) do
    current_positions = positions ++ (generated_results |> Enum.map(&elem(&1, 0)))

    case generate_decision(trade_event, position, current_positions, settings) do
      :exit ->
        generate_decisions(rest, generated_results, trade_event, settings)

      :rebuy ->
        generate_decisions(
          rest,
          [{:skip, %{position | rebuy_notified: true}}, {:rebuy, position}] ++ generated_results,
          trade_event,
          settings
        )

      decision ->
        generate_decisions(
          rest,
          [{decision, position} | generated_results],
          trade_event,
          settings
        )
    end
  end

  def generate_decision(
        %TradeEvent{price: price},
        %Position{
          budget: budget,
          buy_order: nil,
          buy_down_interval: buy_down_interval,
          tick_size: tick_size,
          step_size: step_size
        },
        _positions,
        _settings
      ) do
    price = calculate_buy_price(price, buy_down_interval, tick_size)
    quantity = calculate_quantity(budget, price, step_size)

    {:place_buy_order, price, quantity}
  end

  def generate_decision(
        %TradeEvent{buyer_order_id: order_id},
        %Position{
          buy_order: %Binance.OrderResponse{
            order_id: order_id,
            status: "FILLED"
          },
          sell_order: %Binance.OrderResponse{}
        },
        _positions,
        _settings
      )
      when is_number(order_id) do
    :skip
  end

  def generate_decision(
        %TradeEvent{buyer_order_id: order_id},
        %Position{
          buy_order: %Binance.OrderResponse{
            order_id: order_id
          },
          sell_order: nil
        },
        _positions,
        _settings
      )
      when is_number(order_id) do
    :fetch_buy_order
  end

  def generate_decision(
        %TradeEvent{},
        %Position{
          buy_order: %Binance.OrderResponse{
            status: "FILLED",
            price: buy_price
          },
          sell_order: nil,
          profit_interval: profit_interval,
          tick_size: tick_size
        },
        _positions,
        _settings
      ) do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    {:place_sell_order, sell_price}
  end

  def generate_decision(
        %TradeEvent{},
        %Position{
          sell_order: %Binance.OrderResponse{status: "FILLED"}
        },
        _positions,
        settings
      ) do
    if settings.status != "shutdown" do
      :finished
    else
      :exit
    end
  end

  def generate_decision(
        %TradeEvent{
          seller_order_id: order_id
        },
        %Position{
          sell_order: %Binance.OrderResponse{
            order_id: order_id
          }
        },
        _positions,
        _settings
      ) do
    :fetch_sell_order
  end

  def generate_decision(
        %TradeEvent{price: current_price},
        %Position{
          buy_order: %Binance.OrderResponse{price: buy_price},
          rebuy_interval: rebuy_interval,
          rebuy_notified: false
        },
        positions,
        settings
      ) do
    if trigger_rebuy?(buy_price, current_price, rebuy_interval) and settings.status != "shutdown" and
         length(positions) < settings.chunks do
      :rebuy
    else
      :skip
    end
  end

  def generate_decision(%TradeEvent{}, %Position{}, _positions, _settings) do
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
         %Position{
           id: id,
           symbol: symbol
         } = position,
         _settings
       ) do
    Logger.info(
      "Position (#{symbol}/#{id}): " <>
        "Placing a BUY order @ #{price}, quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    :ok = broadcast_order(order)

    {:ok, %{position | buy_order: order}}
  end

  defp execute_decision(
         {:place_sell_order, sell_price},
         %Position{
           id: id,
           symbol: symbol,
           buy_order: %Binance.OrderResponse{
             orig_qty: quantity
           }
         } = position,
         _settings
       ) do
    Logger.info(
      "Position (#{symbol}/#{id}): The BUY order is now filled. " <>
        "Placing a SELL order @ #{sell_price}, quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

    :ok = broadcast_order(order)

    {:ok, %{position | sell_order: order}}
  end

  defp execute_decision(
         :fetch_buy_order,
         %Position{
           id: id,
           symbol: symbol,
           buy_order:
             %Binance.OrderResponse{
               order_id: order_id,
               transact_time: timestamp
             } = buy_order
         } = position,
         _settings
       ) do
    Logger.info("Position (#{symbol}/#{id}): The BUY order is now partially filled")

    {:ok, %Binance.Order{} = current_buy_order} =
      @binance_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_buy_order)
    buy_order = %{buy_order | status: current_buy_order.status}
    {:ok, %{position | buy_order: buy_order}}
  end

  defp execute_decision(
         :finished,
         %Position{
           id: id,
           symbol: symbol
         },
         settings
       ) do
    new_position = generate_fresh_position(settings)
    Logger.info("Position (#{symbol}/#{id}): Trade cycle finished")
    {:ok, new_position}
  end

  defp execute_decision(
         :fetch_sell_order,
         %Position{
           id: id,
           symbol: symbol,
           sell_order:
             %Binance.OrderResponse{
               order_id: order_id,
               transact_time: timestamp
             } = sell_order
         } = position,
         _settings
       ) do
    Logger.info("Position (#{symbol}/#{id}): The SELL order is now partially filled")

    {:ok, %Binance.Order{} = current_sell_order} =
      @binance_client.get_order(symbol, timestamp, order_id)

    :ok = broadcast_order(current_sell_order)
    sell_order = %{sell_order | status: current_sell_order.status}
    {:ok, %{position | sell_order: sell_order}}
  end

  defp execute_decision(
         :rebuy,
         %Position{
           id: id,
           symbol: symbol
         },
         settings
       ) do
    new_position = generate_fresh_position(settings)
    Logger.info("Position (#{symbol}/#{id}): Rebuy triggered. Starting a new position")
    {:ok, new_position}
  end

  defp execute_decision(:skip, state, _settings) do
    {:ok, state}
  end

  defp broadcast_order(%Binance.OrderResponse{} = response) do
    response
    |> convert_to_order
    |> broadcast_order
  end

  defp broadcast_order(%Binance.Order{} = order) do
    Phoenix.PubSub.broadcast(Core.PubSub, "ORDERS:#{order.symbol}", order)
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

  def fetch_symbol_settings(symbol) do
    exchange_info =
      @binance_client.get_exchange_info()

    db_settings = Repo.get_by!(Settings, symbol: symbol)

    merge_filters_into_settings(exchange_info, db_settings, symbol)
  end

  def merge_filters_into_settings(exchange_info, db_settings, symbol) do
    symbol_filters =
      exchange_info
      |> elem(1)
      |> Map.get(:symbols)
      |> Enum.find(&(&1["symbol"] == symbol))
      |> Map.get("filters")

    tick_size =
      symbol_filters
      |> Enum.find(&(&1["filterType"] == "PRICE_FILTER"))
      |> Map.get("tickSize")

    step_size =
      symbol_filters
      |> Enum.find(&(&1["filterType"] == "LOT_SIZE"))
      |> Map.get("stepSize")

    Map.merge(
      %{
        tick_size: tick_size,
        step_size: step_size
      },
      Map.from_struct(db_settings)
    )
  end

  def generate_fresh_position(settings, id \\ :os.system_time(:millisecond)) do
    %{
      struct(Position, settings)
      | id: id,
        budget: Decimal.div(settings.budget, settings.chunks),
        rebuy_notified: false
    }
  end

  def update_status(symbol, status) when is_binary(symbol) and is_binary(status) do
    Repo.get_by(Settings, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> Repo.update()
  end
end
