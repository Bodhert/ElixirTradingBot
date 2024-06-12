defmodule Hedgehog.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      consolidate_protocols: Mix.env() == :prod
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex, :wx, :observer, :runtime_tools]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      sobelow: ["cmd mix sobelow"],
      setup: [
        "ecto.drop",
        "ecto.create",
        "ecto.migrate",
        "cmd --app naive --app streamer mix seed"
      ],
      "test.integration": [
        "setup",
        "test --only integration"
      ]
    ]
  end
end
