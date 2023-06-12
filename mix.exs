defmodule RedisGraph.MixProject do
  use Mix.Project

  @description "A RedisGraph client implementation."
  @repo_url "https://github.com/crflynn/redisgraph-ex"
  @version "0.1.0"

  def project do
    [
      app: :redisgraph,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      deps: deps(),
      # hex
      description: @description,
      package: package(),
      source_url: @repo_url,
      homepage_url: @repo_url,
      docs: docs()
    ]
  end

  defp aliases do
    [
      docopen: ["docs", "cmd open doc/index.html"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # GRAPH.QUERY test MATCH (p:person)-[v:visited]->(c:country) RETURN p
  # ["GRAPH.EXPLAIN", "test", "(p:person)-[v:visited]->(c:country) RETURN p"]
  defp package do
    [
      maintainers: ["Christopher Flynn"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @repo_url,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 1.2"},
      {:castore, ">= 0.0.0"},
      {:scribe, "~> 0.10.0"},

      # dev
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},

      # test
      {:excoveralls, "~> 0.16.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
