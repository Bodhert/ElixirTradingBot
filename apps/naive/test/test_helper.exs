ExUnit.start()

Application.ensure_all_started(:mox)
# here I differed a little bit from the book cause in has
# warning_as_errors turned on and i needed compile time checks
# Mox.defmock(Test.BinanceMock, for: BinanceMock)
# Mox.defmock(Test.Naive.LeaderMock, for: Naive.Leader)
# Mox.defmock(Test.LoggerMock, for: Core.Test.Logger)
# Mox.defmock(Test.PubSubMock, for: Core.Test.PubSub)
