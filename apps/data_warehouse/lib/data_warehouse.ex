defmodule DataWarehouse do
  @moduledoc """
  Documentation for `DataWarehouse`.
  """

  alias DataWarehouse.Subscriber.DynamicSupervisor

  def start_storing(stream, symbol) do
    stream
    |> to_topic(symbol)
    |> DynamicSupervisor.start_worker()
  end

  def stop_storing(stream, symbol) do
    stream
    |> to_topic(symbol)
    |> DynamicSupervisor.stop_worker()
  end

  defp to_topic(stream, symbol) do
    [stream, symbol]
    |> Enum.map(&String.upcase/1)
    |> Enum.join(":")
  end
end
