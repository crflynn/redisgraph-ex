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
  """
  alias RedisGraph.Util

  @type t() :: %__MODULE__{
          id: integer(),
          alias: String.t(),
          label: String.t(),
          properties: %{optional(String.t()) => any()}
        }

  defstruct [:id, :alias, :label, properties: %{}]

  @doc """
  Creates a new Node.

  ## Example

      john = Node.new(%{
        label: "person",
        properties: %{
          name: "John Doe",
          age: 33
        }
      })
  """
  @spec new(map()) :: t()
  def new(map) do
    struct(__MODULE__, map)
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

    label =
      case is_nil(node.label) do
        true -> ""
        false -> node.label
      end

    "(" <> alias_ <> ":" <> label <> properties_to_string(node) <> ")"
  end

  @doc """
  Compare two Nodes with respect to equality.

  Comparison logic:

  * if labels differ then returns false
  * if properties differ then returns false
  * otherwise returns true
  """
  @spec compare(t(), t()) :: boolean()
  def compare(left, right) do
    cond do
      left.id != right.id -> false
      left.alias != right.alias -> false
      left.label != right.label -> false
      map_size(left.properties) != map_size(right.properties) -> false
      not Map.equal?(left.properties, right.properties) -> false
      true -> true
    end
  end
end
