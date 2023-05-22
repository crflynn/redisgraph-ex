defmodule RedisGraph.Node do
  @moduledoc """
  A Node member of a Graph.

  Nodes have an alias which uniquely identifies them in a Graph. Nodes
  must have an alias in order for their associated Graph to be committed
  to the database.

  Nodes have a label which is analogous to a type definition. Nodes can
  be queried based on their label, e.g. ``person`` or ``place`` or ``food``.

  Nodes may optionally have properties, a map of values associated with
  the entity. These properties can be returned by database queries.

  Nodes may have aliases. When adding a `RedisGraph.Node` to a
  `RedisGraph.Graph`, a random alias may be set on the Node prior
  to being added to the Graph if it does not already have one.

  Nodes which are created as the result of a ``MATCH`` query in a
  `RedisGraph.QueryResult` will also have numeric ids which are
  internal to the graph in the database.
  """
  alias RedisGraph.Util

  @type t() :: %__MODULE__{
          id: integer(),
          alias: String.t(),
          labels: List.t(),
          properties: %{optional(String.t()) => any()}
        }

  defstruct [:id, :alias, labels: [], properties: %{}]

  @doc """
  Creates a new Node.

  ## Example

      john = Node.new(%{
        labels: ["person"],
        properties: %{
          name: "John Doe",
          age: 33
        }
      })
  """
  @spec new(map()) :: t()
  def new(map) do
    node = struct(__MODULE__, map)
    if(is_nil(node.alias), do: set_alias_if_nil(node), else: node)
  end

  @doc "Sets the node's alias if it is `nil`."
  @spec set_alias_if_nil(t()) :: t()
  def set_alias_if_nil(node) do
    if is_nil(node.alias) do
      %{node | alias: Util.random_string()}
    else
      node
    end
  end

  @doc "Converts the properties to a query-appropriate string."
  @spec properties_to_string(t()) :: String.t()
  def properties_to_string(node) do
    inner =
      Map.keys(node.properties)
      |> Enum.map(fn key -> "#{key}:#{Util.quote_string(node.properties[key])}" end)
      |> Enum.join(",")

    if String.length(inner) > 0 do
      "{" <> inner <> "}"
    else
      ""
    end
  end

  @doc "Converts the node to a query-appropriate string."
  @spec to_query_string(t()) :: String.t()
  def to_query_string(node) do
    alias_ =
      case is_nil(node.alias) do
        true -> ""
        false -> node.alias
      end

    labels =
      cond do
        is_list(node.labels) and length(node.labels) > 0 -> ":" <> Enum.join(node.labels, ":")
        true -> ""
      end

    "(" <> alias_ <> labels <> properties_to_string(node) <> ")"
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
      not left.labels == right.labels -> false
      map_size(left.properties) != map_size(right.properties) -> false
      not Map.equal?(left.properties, right.properties) -> false
      true -> true
    end
  end
end
