defmodule RedisGraph.QueryResult do
  alias RedisGraph.Edge
  alias RedisGraph.Node

  require Logger

  @result_set_column_types [:COLUMN_UNKNOWN, :COLUMN_SCALAR, :COLUMN_NODE, :COLUMN_RELATION]

  @result_set_scalar_types [
    :PROPERTY_UNKNOWN,
    :PROPERTY_NULL,
    :PROPERTY_STRING,
    :PROPERTY_INTEGER,
    :PROPERTY_BOOLEAN,
    :PROPERTY_DOUBLE
  ]

  @labels_added "Labels added"
  @nodes_created "Nodes created"
  @nodes_deleted "Nodes deleted"
  @relationships_deleted "Relationships deleted"
  @properties_set "Properties set"
  @relationships_created "Relationships created"
  @internal_execution_time "internal execution time"

  @enforce_keys [:graph, :raw_result_set]
  defstruct [:graph, :raw_result_set, :header, :result_set, :statistics]

  def new(map) do
    s = struct(__MODULE__, map)

    if length(s.raw_result_set) == 1 do
      %{s | statistics: parse_statistics(Enum.at(s.raw_result_set, 0))}
    else
      %{parse_results(s) | statistics: parse_statistics(Enum.at(s.raw_result_set, -1))}
    end
  end

  def is_empty(query_result) do
    length(query_result.raw_result_set) == 0
  end

  defp parse_statistics(raw_statistics) do
    stats = [
      @labels_added,
      @nodes_created,
      @properties_set,
      @relationships_created,
      @nodes_deleted,
      @relationships_deleted,
      @internal_execution_time
    ]

    stats
    |> Enum.map(fn s -> {s, get_value(s, raw_statistics)} end)
    |> Enum.into(%{})
  end

  defp get_value(stat, [raw_statistic | raw_statistics]) do
    case extract_value(stat, raw_statistic) do
      nil -> get_value(stat, raw_statistics)
      value -> value
    end
  end

  defp get_value(_stat, []) do
    nil
  end

  defp extract_value(stat, raw_statistic) do
    if String.contains?(raw_statistic, stat) do
      raw_statistic
      |> String.split(": ")
      |> Enum.at(1)
      |> String.split(" ")
      |> Enum.at(0)
    else
      nil
    end
  end

  def parse_results(query_result) do
    header = parse_header(query_result.raw_result_set)

    if length(header) > 0 do
      %{
        query_result
        | header: header,
          result_set: parse_records(query_result.graph, query_result.raw_result_set)
      }
    else
      query_result
    end
  end

  defp parse_header(raw_result_set) do
    Enum.at(raw_result_set, 0)
  end

  defp parse_records(graph, raw_result_set) do
    header = parse_header(raw_result_set)

    Enum.at(raw_result_set, 1)
    |> Enum.map(&parse_row(graph, header, &1))
  end

  defp parse_row(graph, header, row) do
    row
    |> Enum.with_index()
    |> Enum.map(&parse_cell(graph, header, &1, &2))
  end

  defp parse_cell(graph, header, cell, idx) do
    cell_type = Enum.at(Enum.at(header, idx), 0)
    parse_cell(graph, cell, Enum.at(@result_set_column_types, cell_type))
  end

  defp parse_cell(_graph, cell, :COLUMN_SCALAR) do
    {scalar_type, _} = Integer.parse(Enum.at(cell, 0))
    value = Enum.at(cell, 1)
    parse_scalar(value, Enum.at(@result_set_scalar_types, scalar_type))
  end

  defp parse_cell(graph, cell, :COLUMN_NODE) do
    parse_node(graph, cell)
  end

  defp parse_cell(graph, cell, :COLUMN_RELATION) do
    parse_edge(graph, cell)
  end

  defp parse_scalar(_value, :PROPERTY_NULL) do
    nil
  end

  defp parse_scalar(value, :PROPERTY_STRING) do
    to_string(value)
  end

  defp parse_scalar(value, :PROPERTY_INTEGER) do
    {i, _} = Integer.parse(value)
    i
  end

  defp parse_scalar(value, :PROPERTY_BOOLEAN) do
    case value do
      "true" -> true
      "false" -> false
    end
  end

  defp parse_scalar(value, :PROPERTY_DOUBLE) do
    {f, _} = Float.parse(value)
    f
  end

  defp parse_scalar(_value, :PROPERTY_UNKNOWN) do
    Logger.warn("Unknown scalar type")
    nil
  end

  defp parse_node(graph, cell) do
    node_id = Enum.at(cell, 0)

    label =
      if length(Enum.at(cell, 1)) > 0 do
        graph.get_label(Enum.at(Enum.at(cell, 1), 0))
      else
        nil
      end

    properties = parse_entity_properties(graph, Enum.at(cell, 2))

    %Node{
      id: node_id,
      label: label,
      properties: properties
    }
  end

  defp parse_edge(graph, cell) do
    {edge_id, relation, src_node, dest_node, properties} = cell

    {edge_id, _} = Float.parse(edge_id)
    relation = graph.get_relation(relation)
    {src_node, _} = Float.parse(src_node)
    {dest_node, _} = Float.parse(dest_node)

    properties = parse_entity_properties(graph, properties)

    %Edge{
      id: edge_id,
      relation: relation,
      src_node: src_node,
      dest_node: dest_node,
      properties: properties
    }
  end

  defp parse_entity_properties(graph, properties) do
    properties
    |> Enum.map(fn [k | v] ->
      prop_name = graph.get_property(k)
      prop_value = parse_cell(graph, v, :COLUMN_SCALAR)
      {prop_name, prop_value}
    end)
    |> Enum.into(%{})
  end

  def pretty_print(_result_set) do
    "todo"
  end

  defp get_stat(query_result, stat) do
    Map.get(query_result.statistics, stat, 0)
  end

  def labels_added(query_result) do
    get_stat(query_result, @labels_added)
  end

  def nodes_created(query_result) do
    get_stat(query_result, @nodes_created)
  end

  def nodes_deleted(query_result) do
    get_stat(query_result, @nodes_deleted)
  end

  def properties_set(query_result) do
    get_stat(query_result, @properties_set)
  end

  def relationships_created(query_result) do
    get_stat(query_result, @relationships_created)
  end

  def relationships_deleted(query_result) do
    get_stat(query_result, @relationships_deleted)
  end

  def run_time_ms(query_result) do
    get_stat(query_result, @internal_execution_time)
  end
end
