defmodule RedisGraph.Node do
  alias RedisGraph.Util

  @type t() :: %__MODULE__{
          id: integer(),
          alias: atom(),
          labels: [String.t()],
          properties: %{}
        }

  defstruct [:id, :alias, labels: [], properties: %{}]

  @spec new() :: t()
  def new() do
    new(%{})
  end

  @spec new(map()) :: t()
  def new(map) when is_map(map) do
    node = struct(__MODULE__, map)
    if(is_nil(node.alias), do: set_alias_if_nil(node), else: node)
  end

  @doc "Sets the node's alias if it is `nil`."
  @spec set_alias_if_nil(t()) :: t()
  def set_alias_if_nil(node) do
    if is_nil(node.alias) do
      alias =  Util.random_string() |> String.to_atom()
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
