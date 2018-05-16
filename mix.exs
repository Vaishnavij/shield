defmodule Shield.Mixfile do
  use Mix.Project

  def project do
    [app: :shield,
     version: "0.7.2",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     aliases: aliases(),
     deps: deps(),
     docs: [extras: ["README.md"]]]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Shield, []},
     applications: [:phoenix, :cowboy, :logger, :gettext,
                    :phoenix_ecto, :authable, :shield_notifier]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.2.0"},
     {:phoenix_ecto, "~> 3.2.1"},
     {:gettext, "~> 0.13"},
     {:cowboy, "~> 1.0"},
     {:authable, "~> 0.8.0"},
     {:shield_notifier, "~> 0.2.0"},
     {:cors_plug, "~> 1.1.4"},
     {:poison, "~> 2.0 or ~> 3.0 or ~> 3.1"},
     {:ex_machina, "~> 1.0.1", only: :test},
     {:credo, "~> 0.6.1", only: :dev},
     {:ex_doc, ">= 0.14.5", only: :dev},
     {:dialyxir, "~> 0.4", only: [:dev], runtime: false}
   ]
  end

  # Aliases are shortcut or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"]]
  end

  defp description do
    """
    Shield is an OAuth2 Provider hex package and also a standalone microservice
    build top of the Phoenix Framework and 'authable' package.
    """
  end

  defp package do
    [name: :shield,
     files: ["lib", "web", "priv", "mix.exs", "README.md"],
     maintainers: ["Mustafa Turan"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/mustafaturan/shield"}]
  end
end
