import Config

config :binance_mock,
  use_cached_exchange_info: false

config :core,
  logger: Logger,
  pubsub_client: Phoenix.PubSub

config :data_warehouse,
  ecto_repos: [DataWarehouse.Repo]

config :data_warehouse, DataWarehouse.Repo,
  database: "data_warehouse",
  username: "postgres",
  password: "hedgehogSecretPassword",
  hostname: "localhost"

config :streamer,
  binance_client: BinanceMock,
  ecto_repos: [Streamer.Repo]

config :streamer, Streamer.Repo,
  database: "streamer",
  username: "postgres",
  password: "hedgehogSecretPassword",
  hostname: "localhost"

config :naive,
  binance_client: BinanceMock,
  ecto_repos: [Naive.Repo],
  leader: Naive.Leader,
  repo: Naive.Repo,
  trading: %{
    defaults: %{
      chunks: 5,
      budget: 1000,
      buy_down_interval: "0.0001",
      profit_interval: "-0.0012",
      rebuy_interval: "0.001"
    }
  }

config :naive, Naive.Repo,
  database: "naive",
  username: "postgres",
  password: "hedgehogSecretPassword",
  hostname: "localhost"

config :logger,
  level: :debug

if File.exists?("config/secrets.exs") do
  import_config("secrets.exs")
end

import_config "#{config_env()}.exs"
