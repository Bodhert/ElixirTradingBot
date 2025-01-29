defmodule Naive.Support.Mocks do
  @moduledoc """
  Compile time mocks for avoiding warnings
  """

  Mox.defmock(Test.BinanceMock, for: BinanceMock)
  Mox.defmock(Test.LoggerMock, for: Core.Test.Logger)
  Mox.defmock(Test.PubSubMock, for: Core.Test.PubSub)
end
