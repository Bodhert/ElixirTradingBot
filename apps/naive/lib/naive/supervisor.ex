defmodule Naive.Supervisor do
  @moduledoc """
   Base supervisor of the naive strategy, in charge of supervising
   dynamic symbol supervisor and start autotrading task
  """
  use Supervisor

  alias Naive.DynamicTraderSupervisor

  @registry :naive_traders

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Registry, [keys: :unique, name: @registry]},
      {DynamicTraderSupervisor, []},
      {Task, fn -> DynamicTraderSupervisor.autostart_workers() end}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
