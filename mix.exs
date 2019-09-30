defmodule RedisGraph.MixProject do
  use Mix.Project

  @description "A RedisGraph client implementation."
  @repo_url "https://github.com/crflynn/redisgraph-ex"
  @version "0.1.0"

  def project do
    [
      app: :redisgraph,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      deps: deps(),
      # hex
      description: @description,
      package: package(),
      source_url: @repo_url,
      homepage_url: @repo_url
    ]
  end

  defp aliases do
    [
      docs: ["docs", "cmd open doc/index.html"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package() do
    [
      maintainers: ["Christopher Flynn"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, ">= 0.10.2"},
      {:scribe, "~> 0.10"},

      # dev
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},

      # test
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end
end
