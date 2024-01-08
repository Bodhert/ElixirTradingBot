defmodule Naive.DynamicSymbolSupervisor do
  @moduledoc """
  Dynamic symbol supervisor, in charge of supervise runtime created symbols
  """
  use DynamicSupervisor

  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def shutdown_worker(symbol) when is_binary(symbol) do
    symbol = String.upcase(symbol)

    case Core.ServiceSupervisor.get_pid(symbol) do
      nil ->
        Logger.warning("Trading on #{symbol} already stopped")
        {:ok, _settings} = Core.ServiceSupervisor.update_status(symbol, "off")

      _pid ->
        Logger.info("Shutdown of trading on #{symbol} initialized")
        {:ok, settings} = Core.ServiceSupervisor.update_status(symbol, "shutdown")
        Naive.Leader.notify(:settings_updated, settings)
        {:ok, settings}
    end
  end

  def autostart_workers do
    Core.ServiceSupervisor.autostart_workers()
  end

  def start_worker(symbol) do
    Core.ServiceSupervisor.start_worker(symbol)
  end

  def stop_worker(symbol) do
    Core.ServiceSupervisor.stop_worker(symbol)
  end

end
