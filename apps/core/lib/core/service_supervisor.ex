defmodule Core.ServiceSupervisor do
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Naive.Repo
  alias Naive.Schema.Settings

  def autostart_workers do
    fetch_symbols_to_start()
    |> Enum.map(&start_worker/1)
  end

  def start_worker(symbol) when is_binary(symbol) do
    symbol = String.upcase(symbol)

    case get_pid(symbol) do
      nil ->
        Logger.info("Starting trading of #{symbol}")
        {:ok, _settings} = update_status(symbol, "on")

        {:ok, _pid} =
          DynamicSupervisor.start_child(
            Naive.DynamicSymbolSupervisor,
            {Naive.SymbolSupervisor, symbol}
          )

      pid ->
        Logger.warning("Trading on #{symbol} already started")
        {:ok, _settings} = update_status(symbol, "on")
        {:ok, pid}
    end
  end

  def stop_worker(symbol) when is_binary(symbol) do
    symbol = String.upcase(symbol)

    case get_pid(symbol) do
      nil ->
        Logger.warning("Trading on #{symbol} already stopped")
        {:ok, _settings} = update_status(symbol, "off")

      pid ->
        Logger.info("Stopping trading of #{symbol}")

        :ok = DynamicSupervisor.terminate_child(Naive.DynamicSymbolSupervisor, pid)

        {:ok, _settings} = update_status(symbol, "off")
    end
  end

  def get_pid(symbol) do
    Process.whereis(:"Elixir.Naive.SymbolSupervisor-#{symbol}")
  end

  def update_status(symbol, status) when is_binary(symbol) and is_binary(status) do
    Repo.get_by(Settings, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> Repo.update()
  end

  defp start_symbol_supervisor(symbol) do
    DynamicSupervisor.start_child(
      Naive.DynamicSymbolSupervisor,
      {Naive.SymbolSupervisor, symbol}
    )
  end

  defp fetch_symbols_to_start do
    Repo.all(
      from(
        s in Settings,
        where: s.status == "on",
        select: s.symbol
      )
    )
  end
end
