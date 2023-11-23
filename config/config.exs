import Config

config :logger,
  level: :debug

if File.exists?("config/secrets.exs") do
  import_config("secrets.exs")
end

config :naive,
  binance_client: BinanceMock
