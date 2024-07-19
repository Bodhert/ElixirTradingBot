defmodule Naive.Support.Mocks do
  Mox.defmock(Test.BinanceMock, for: BinanceMock)
  Mox.defmock(Test.Naive.LeaderMock, for: Naive.Leader)
  Mox.defmock(Test.LoggerMock, for: Core.Test.Logger)
  Mox.defmock(Test.PubSubMock, for: Core.Test.PubSub)
end
