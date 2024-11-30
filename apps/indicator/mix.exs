defmodule Indicator.MixProject do
  use Mix.Project
  alias Core.Struct.TradeEvent

  def project do
    [
      app: :indicator,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Indicator.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:core, in_umbrella: true},
      {:phoenix_pubsub, "~> 2.0"}
    ]
  end
end
