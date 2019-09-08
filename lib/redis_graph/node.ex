defmodule RedisGraph.Node do
  alias RedisGraph.Util

  defstruct [:id, :alias, :label, properties: %{}]

  def new(map) do
    struct(__MODULE__, map)
  end

  def set_alias_if_nil(node) do
    if is_nil(node.alias) do
      %{node | alias: Util.random_string()}
    else
      node
    end
  end

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

  def left == right do
    cond do
      not is_nil(left.id) and not is_nil(right.id) and Kernel.==(left.id, right.id) -> true
      left.label != right.label -> false
      map_size(left.properties) != map_size(right.properties) -> false
      not Map.equal?(left.properties, right.properties) -> false
      true -> true
    end
  end
end
