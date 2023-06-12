defmodule RedisGraph.Node do
  @moduledoc """
  A Node member of a Graph.

  Nodes have an alias which uniquely identifies them in a Graph. Nodes
  must have an alias. When alias is not provided on initialization,
  a random alias will be set on the Node.

  Nodes may optionally have a list of labels which is analogous to a type definition.
  Nodes can be queried based on their labels, e.g. ``person`` or ``place`` or ``food``.

  Nodes may optionally have properties as well, which is a map of values associated
  with the entity. These properties can be returned by database queries.

  Nodes which are created as the result of a passed query to the graph database
  through `RedisGraph.QueryResult` will also have numeric ids which are
  internal to the graph in the database.
  """
  alias RedisGraph.Util

  @type t() :: %__MODULE__{
          id: integer(),
          alias: atom(),
          labels: [String.t()],
          properties: %{}
        }

  defstruct [:id, :alias, labels: [], properties: %{}]

  @doc """
  Creates a new Node with default arguments.

  ## Example
  ```
  alias RedisGraph.{Node}

  # create a Node
  bob = Node.new()

  ```
  """
  @spec new() :: t()
  def new() do
    new(%{})
  end

  @doc """
  Creates a new Node from provided argument.

  ## Example
  ```
  alias RedisGraph.{Node}

  # create a Node
  bob = Node.new(%{
    alias: :n,
    labels: ["person"],
    properties: %{
      name: "Bob Thomsen",
      age: 22
    }
  })
  ```
  """
  @spec new(map()) :: t()
  def new(map) when is_map(map) do
    node = struct(__MODULE__, map)
    if(is_nil(node.alias), do: set_alias_if_nil(node), else: node)
  end

  @doc "Sets the node's alias to atom if it is `nil`."
  @spec set_alias_if_nil(t()) :: t()
  def set_alias_if_nil(node) do
    if is_nil(node.alias) do
      alias = Util.random_string() |> String.to_atom()
      %{node | alias: alias}
    else
      node
    end
  end

  @doc """
  Compare two Nodes with respect to equality.

  Comparison logic:

  * if ids differ then returns ``false``
  * if aliases differ then returns ``false``
  * if labels differ then returns ``false``
  * if properties differ then returns ``false``
  * otherwise returns ``true``
  """
  @spec compare(t(), t()) :: boolean()
  def compare(left, right) do
    cond do
      left.id != right.id -> false
      left.alias != right.alias -> false
      length(left.labels) != length(right.labels) -> false
      left.labels != right.labels -> false
      map_size(left.properties) != map_size(right.properties) -> false
      not Map.equal?(left.properties, right.properties) -> false
      true -> true
    end
  end
end
