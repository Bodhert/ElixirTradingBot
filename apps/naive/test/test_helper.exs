
Application.ensure_all_started(:mimic)
Mimic.Copy(Binance)
Mimic.Copy(Phoenix.PubSub)
Mimic.Copy(BinanceMock)
ExUnit.start(capture_log: true)
