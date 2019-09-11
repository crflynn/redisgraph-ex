# RedisGraph

A [RedisGraph](https://oss.redislabs.com/redisgraph/) client implementation library in Elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `redisgraph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:redisgraph, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/redisgraph](https://hexdocs.pm/redisgraph).

## Example usage

This library uses [Redix](https://github.com/whatyouhide/redix) to communicate with a redisgraph server.

To launch ``redisgraph`` locally, use

```bash
docker run -p 6379:6379 -it --rm redislabs/redisgraph
```

Here is a simple example:

```

which gives the following results:

```elixir
# Commit result statistics
%{
  "Labels added" => nil,
  "Nodes created" => "2",
  "Nodes deleted" => nil,
  "Properties set" => "5",
  "Query internal execution time" => "0.228669",
  "Relationships created" => "1",
  "Relationships deleted" => nil
}

# Query result pretty-printed
+----------------+-------------+-----------------+--------------+
| "p.name"       | "p.age"     | "v.purpose"     | "c.name"     |
+----------------+-------------+-----------------+--------------+
| "John Doe"     | 33          | nil             | "Japan"      |
+----------------+-------------+-----------------+--------------+
```
