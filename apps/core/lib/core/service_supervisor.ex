defmodule Core.ServiceSupervisor do
  require Logger

  import Ecto.Query, only: [from: 2]

  defmacro __using__(opts) do
    IO.inspect(opts)
    {:ok, repo} = Keyword.fetch(opts, :repo)
    {:ok, schema} = Keyword.fetch(opts, :schema)
    {:ok, module} = Keyword.fetch(opts, :module)
    {:ok, worker_module} = Keyword.fetch(opts, :worker_module)

    quote location: :keep do
      use DynamicSupervisor

      def start_link(init_arg) do
        IO.inspect(__MODULE__, label: "mira mira jojoj")
        IO.inspect(unquote(module), label: "mira mira jojoj - 2")
        # IO.inspect(module, label: "mira mira jojoj - 3")
        Core.ServiceSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
      end

      def init(_init_arg) do
        Core.ServiceSupervisor.init(strategy: :one_for_one)
      end

      def autostart_workers do
        Core.ServiceSupervisor.autostart_workers(
          unquote(repo),
          unquote(schema),
          unquote(module),
          unquote(worker_module)
        )
      end

      def start_worker(symbol) do
        Core.ServiceSupervisor.start_worker(
          symbol,
          unquote(repo),
          unquote(schema),
          unquote(module),
          unquote(worker_module)
        )
      end

      def stop_worker(symbol) do
        Core.ServiceSupervisor.stop_worker(
          symbol,
          unquote(repo),
          unquote(schema),
          unquote(module),
          unquote(worker_module)
        )
      end

      defp get_pid(symbol) do
        Core.ServiceSupervisor.get_pid(unquote(worker_module), symbol)
      end

      defp update_status(status, symbol) do
        Core.ServiceSupervisor.update_status(
          symbol,
          status,
          unquote(repo),
          unquote(schema)
        )
      end
    end
  end

  defdelegate start_link(module, args, opts), to: DynamicSupervisor
  defdelegate init(opts), to: DynamicSupervisor

  def autostart_workers(repo, schema, module, worker_module) do
    fetch_symbols_to_start(repo, schema)
    |> Enum.map(&start_worker(&1, repo, schema, module, worker_module))
  end

  def start_worker(symbol, repo, schema, module, worker_module) when is_binary(symbol) do
    symbol = String.upcase(symbol)

    case get_pid(worker_module, symbol) do
      nil ->
        Logger.info("Starting #{worker_module} worker for #{symbol}")
        {:ok, _settings} = update_status(symbol, "on", repo, schema)

        {:ok, _pid} =
          DynamicSupervisor.start_child(
            module,
            {worker_module, symbol}
          )

      pid ->
        Logger.warning("#{worker_module} worker for #{symbol} already started")
        {:ok, _settings} = update_status(symbol, "on", repo, schema)
        {:ok, pid}
    end
  end

  def stop_worker(symbol, repo, schema, _module, worker_module) when is_binary(symbol) do
    symbol = String.upcase(symbol)

    case get_pid(worker_module, symbol) do
      nil ->
        Logger.warning("#{worker_module} worker for #{symbol} already stopped")
        {:ok, _settings} = update_status(symbol, "off", repo, schema)

      pid ->
        Logger.info("Stopping #{worker_module} worker for #{symbol}")

        :ok = DynamicSupervisor.terminate_child(Naive.DynamicSymbolSupervisor, pid)

        {:ok, _settings} = update_status(symbol, "off", repo, schema)
    end
  end

  def get_pid(worker_module, symbol) do
    Process.whereis(:"#{worker_module}-#{symbol}")
  end

  def update_status(symbol, status, repo, schema) when is_binary(symbol) and is_binary(status) do
    repo.get_by(schema, symbol: symbol)
    |> Ecto.Changeset.change(%{status: status})
    |> repo.update()
  end

  def fetch_symbols_to_start(repo, schema) do
    repo.all(
      from(
        s in schema,
        where: s.status == "on",
        select: s.symbol
      )
    )
  end
end
