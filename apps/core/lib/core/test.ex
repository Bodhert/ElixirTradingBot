defmodule Core.Test do
  @moduledoc """
  Module for mocking external dependies in which we do not have
  control of.
  """

  defmodule PubSub do
    @moduledoc """
    Pub sub mock
    """

    @type t :: atom
    @type topic :: binary
    @type message :: term

    @callback subscribe(t, topic) :: :ok | {:error, term}
    @callback broadcast(t, topic, message) :: :ok | {:error, term}
  end

  defmodule Logger do
    @moduledoc """
    Logger mock
    """

    @type message :: binary

    @callback info(message) :: :ok
  end
end
