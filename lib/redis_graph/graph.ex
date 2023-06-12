defmodule RedisGraph.Graph do
  @moduledoc """
  A Graph that represents a RedisGraph database
  and consists of the `name` property.

  A name is required for each graph.
  """

  @type t() :: %__MODULE__{name: String.t()}

  @enforce_keys [:name]
  defstruct [:name]

  @doc """
  Create a graph from a map.

  ## Example
  ```
  alias RedisGraph.{Graph}

  # Create a graph
  graph = Graph.new(%{
    name: "social"
  })

  ```
  """
  @spec new(%{name: String.t()}) :: t()
  def new(%{name: name} = map) when is_binary(name) do
    struct(__MODULE__, map)
  end
end
