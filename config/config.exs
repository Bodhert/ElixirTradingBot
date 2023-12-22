import Config

config :naive, Naive.Repo,
  database: "naive_repo",
  username: "user",
  password: "pass",
  hostname: "localhost"

config :logger,
  level: :debug

if File.exists?("config/secrets.exs") do
  import_config("secrets.exs")
end

config :naive,
  ecto_repos: [Naive.Repo],
  binance_client: BinanceMock

config :naive, Naive.Repo,
  database: "naive",
  username: "postgres",
  password: "hedgehogSecretPassword",
  hostname: "localhost"
