defmodule Naive.Supervisor do
  @moduledoc """
   Base supervisor of the naive strategy, in charge of supervising
   dynamic symbol supervisor and start autotrading task
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      Naive.DynamicSymbolSupervisor,
      {Task, fn -> Naive.DynamicSymbolSupervisor.autostart_workers() end}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
