defmodule Core.Struct.TradeEvent do
  @moduledoc """
  Trade event struct
  """
  defstruct [
    :event_type,
    :event_time,
    :symbol,
    :trade_id,
    :price,
    :quantity,
    :buyer_order_id,
    :seller_order_id,
    :trade_time,
    :buyer_market_maker
  ]
end
