defmodule Streamer.Binance do
  @streamer_endpoint "wss://stream.binance.com:9443/ws/"
  use WebSockex

  def start_link(symbol) do
    symbol = String.downcase(symbol)

    WebSockex.start_link(
      "#{@streamer_endpoint}#{symbol}@trade",
      __MODULE__,
      nil
    )
  end

  def handle_frame({type, msg}, state) do
    IO.puts "Recieved MSG - Type: #{inspect type} -- Message: #{inspect msg}"
    {:ok, state}
  end



end
