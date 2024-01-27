import Config

config :data_warehouse,
  ecto_repos: [DataWarehouse.Repo]

config :data_warehouse, DataWarehouse.Repo,
  database: "data_warehouse",
  username: "postgres",
  password: "hedgehogSecretPassword",
  hostname: "localhost"

config :streamer,
  ecto_repos: [Streamer.Repo]

config :streamer, Streamer.Repo,
  database: "streamer",
  username: "postgres",
  password: "hedgehogSecretPassword",
  hostname: "localhost"

config :naive,
  ecto_repos: [Naive.Repo],
  binance_client: BinanceMock,
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
