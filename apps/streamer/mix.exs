defmodule Streamer.MixProject do
  use Mix.Project

  def project do
    [
      app: :streamer,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_options: [
        warnings_as_errors: true
      ],
      aliases: aliases()
    ]
  end

  defp aliases() do
    [
      seed: ["run priv/seed_settings.exs"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Streamer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:binance_mock, in_umbrella: true},
      {:core, in_umbrella: true},
      {:ecto_sql, "~> 3.0"},
      {:ecto_enum, "~> 1.4"},
      {:jason, "~> 1.2"},
      {:phoenix_pubsub, "~> 2.0"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:postgrex, ">= 0.0.0"},
      {:websockex, "~> 0.4"}
    ]
  end
end
