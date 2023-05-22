defmodule RedisGraph.QueryResult do
  @moduledoc """
  A QueryResult containing returned fields and query metadata.

  The resulting struct contains the result set header and records,
  statistics about the query executed, and referential lists of entity
  identifiers, specifically labels, property keys, and relationship types.

  The labels refer to the `label` attribute of either Node entities
  in the graph, The property keys are the keys found in any Node or Edge
  property maps. The relationship types are the `relation` attributes of
  Edge entities in the graph.

  ## Example

  ```elixir
  # Create a query to fetch some data
  query = "MATCH (p:person)-[v:visited]->(c:country) RETURN p.name, p.age, v.purpose, c.name"

  # Execute the query
  {:ok, query_result} = RedisGraph.query(conn, graph.name, query)

  # Show the resulting statistics
  IO.inspect(query_result.statistics)

  # Pretty print the results using the Scribe lib
  IO.puts(QueryResult.pretty_print(query_result))
  ```

  which gives the following results:

  ```elixir
  # Query result statistics
  %{
    "Labels added" => nil,
    "Nodes created" => nil,
    "Nodes deleted" => nil,
    "Properties set" => nil,
    "Query internal execution time" => "0.228669",
    "Relationships created" => nil,
    "Relationships deleted" => nil
  }

  # Pretty printed output
  +----------------+-------------+-----------------+--------------+
  | "p.name"       | "p.age"     | "v.purpose"     | "c.name"     |
  +----------------+-------------+-----------------+--------------+
  | "John Doe"     | 33          | nil             | "Japan"      |
  +----------------+-------------+-----------------+--------------+
  ```
  """
  alias RedisGraph.Edge
  alias RedisGraph.Node

  @labels_added "Labels added"
  @nodes_created "Nodes created"
  @nodes_deleted "Nodes deleted"
  @relationships_deleted "Relationships deleted"
  @properties_set "Properties set"
  @relationships_created "Relationships created"
  @query_internal_execution_time "Query internal execution time"

  @graph_removed_internal_execution_time "Graph removed, internal execution time"

  @column_type %{
    COLUMN_UNKNOWN: 0,
    COLUMN_SCALAR: 1,
    COLUMN_NODE: 2,      # Unused, retained for client compatibility.
    COLUMN_RELATION: 3,  # Unused, retained for client compatibility.

  }

  @value_type %{
    VALUE_UNKNOWN: 0,
    VALUE_NULL: 1,
    VALUE_STRING: 2,
    VALUE_INTEGER: 3,
    VALUE_BOOLEAN: 4,
    VALUE_DOUBLE: 5,
    VALUE_ARRAY: 6,
    VALUE_EDGE: 7,
    VALUE_NODE: 8,
    VALUE_PATH: 9,
    VALUE_MAP: 10,
    VALUE_POINT: 11
  }

  @type t() :: %__MODULE__{
          raw_result_set: list(any()) | String.t(),
          header: list(String.t()),
          result_set: list(list(any())),
          statistics: %{String.t() => String.t()}
        }

  @enforce_keys [:conn, :graph_name, :raw_result_set]
  defstruct [
    :conn,
    :graph_name,
    :raw_result_set,
    :header,
    :result_set,
    :statistics,
    :labels,
    :property_keys,
    :relationship_types
  ]

  @doc """
  Create a new QueryResult from a map.

  Pass a map with a connection, graph name, and raw redisgraph result.
  The raw result is the output of the function `Redix.command/2`.
  This function is invoked by the `RedisGraph.command/2` function.

  The functions `RedisGraph.commit/2`, `RedisGraph.query/3`, `RedisGraph.delete/2`,
  and `RedisGraph.merge/3` will also return a new `RedisGraph.QueryResult`.
  """
  @spec new(map()) :: t()
  def new(map) do
    s = struct(__MODULE__, map)

    process_raw_result(s)
  end

  defp process_raw_result(%{raw_result_set: result} = query_result) when is_list(result) do
    if length(result) == 1 do
      %{query_result | statistics: parse_statistics(Enum.at(result, 0))}
    else
      %{
        parse_results(query_result)
        | statistics: parse_statistics(Enum.at(result, -1))
      }
    end
  end

  # process the result of a delete query
  defp process_raw_result(%{raw_result_set: result} = query_result) when is_binary(result) do
    %{query_result | statistics: parse_statistics(result)}
  end

  @doc "Return a boolean indicating emptiness of a QueryResult."
  @spec is_empty(t()) :: boolean()
  def is_empty(query_result) do
    if is_nil(query_result.result_set) or length(query_result.result_set) == 0 do
      true
    else
      false
    end
  end

  defp parse_statistics(raw_statistics) when is_list(raw_statistics) do
    stats = [
      @labels_added,
      @nodes_created,
      @properties_set,
      @relationships_created,
      @nodes_deleted,
      @relationships_deleted,
      @query_internal_execution_time
    ]

    stats
    |> Enum.map(fn s -> {s, get_value(s, raw_statistics)} end)
    |> Enum.into(%{})
  end

  # delete query result
  defp parse_statistics(raw_statistics) when is_binary(raw_statistics) do
    %{
      @labels_added => nil,
      @nodes_created => nil,
      @properties_set => nil,
      @relationships_created => nil,
      @nodes_deleted => nil,
      @relationships_deleted => nil,
      @query_internal_execution_time =>
        extract_value(@graph_removed_internal_execution_time, raw_statistics)
    }
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

  defp parse_header(%{raw_result_set: [header | _tail]} = _query_result) do
    header |> Enum.map(fn h -> Enum.at(h, 1) end)
  end

  defp fetch_metadata(%{conn: conn, graph_name: name} = query_result) do
    labels = parse_procedure_call(RedisGraph.labels(conn, name))
    property_keys = parse_procedure_call(RedisGraph.property_keys(conn, name))
    relationship_types = parse_procedure_call(RedisGraph.relationship_types(conn, name))

    %{
      query_result
      | labels: labels,
        property_keys: property_keys,
        relationship_types: relationship_types
    }
  end

  defp parse_procedure_call(response) do
    case response do
      {:ok, result} ->
        [_columns_array, records_array, _metadata_array] = result
        # e.g. of records_array -- [ [[_value_type, element]], [[_value_type, element]] ]
        Enum.with_index(records_array, fn [[_value_type, element] | _ ], index -> {index, element} end) |> Enum.into(%{})
      {:error, reason} ->
        raise reason
    end
  end

  defp parse_results(%{raw_result_set: [header | _tail]} = query_result) do
    query_result = fetch_metadata(query_result)
    # IO.puts("parse_results")
    # IO.inspect(query_result)
    if length(header) > 0 do
      header = parse_header(query_result)
      # IO.puts("parse_results > header")
      # IO.inspect(header)
      %{
        query_result
        | header: header,
          result_set: parse_records(query_result)
      }
    else
      query_result
    end
  end

  defp parse_records(%{raw_result_set: [_header | [records_array | _statistics]]} = query_result) do
    # IO.puts("parse_records")
    # IO.puts("parse_records > query_result")
    # IO.inspect(query_result)
    # records = List.first(records_array)
    # IO.puts("parse_records > records")
    records = Enum.map(records_array, &parse_row(query_result, &1))
    # IO.inspect(records)
  end

  defp parse_row(%{raw_result_set: [header | _tail]} = query_result, row) do
    # IO.puts("parse_row > query_result")
    # IO.inspect(query_result)
    # IO.puts("parse_row > row")
    # IO.inspect(row)
    # IO.puts("parse_row > row > end")
    # [[value_type | [[ id | [labels | [properties | _]]]]]] = row
    # IO.puts("parse_row > value_type")
    # IO.inspect(value_type)
    # IO.puts("parse_row > id")
    # IO.inspect(id)
    # IO.puts("parse_row > labels")
    # IO.inspect(labels)
    # IO.puts("parse_row > properties")
    # IO.inspect(properties)
    # IO.puts("parse_row > end")
    # Enum.with_index(row)
    # |> IO.inspect |> Enum.map(fn {cell, idx} ->
    #   parse_cell(query_result, cell, header |> Enum.at(idx) |> Enum.at(0))
    # end)
    cells = Enum.map(row, fn cell -> parse_cell(query_result, cell) end)
    IO.puts("parse_row > cells")
    IO.inspect(cells)
  end

  def extract_node_value(query_result, value) do

  end

  # https://oss.redislabs.com/redisgraph/client_spec/
  defp parse_cell(query_result, cell, 1) do
    parse_scalar(query_result, cell)
  end

  defp parse_cell(query_result, cell, 2) do
    parse_node(query_result, cell)
  end

  defp parse_cell(query_result, cell, 3) do
    parse_edge(query_result, cell)
  end

  defp parse_cell(query_result, cell) do
    IO.puts("parse_cell > cell")
    IO.inspect(cell)
    [value_type | [value]] = cell
    res = cond do
      value_type == @value_type[:VALUE_NODE] -> parse_node(query_result, value)
      value_type == @value_type[:VALUE_EDGE] -> parse_edge(query_result, value)
      value_type == @value_type[:VALUE_NULL] || value_type == @value_type[:VALUE_INTEGER] || value_type == @value_type[:VALUE_STRING] -> value
      value_type == @value_type[:VALUE_BOOLEAN] -> if(value == "true", do: true, else: false)
      value_type == @value_type[:VALUE_DOUBLE] -> String.to_float(value)
      value_type == @value_type[:VALUE_ARRAY] || value_type == @value_type[:VALUE_PATH] || value_type == @value_type[:VALUE_MAP] || value_type == @value_type[:VALUE_POINT] -> "will be implemented in future"
      true -> "unknown value type"
    end
    IO.puts("parse_cell > res")
    IO.inspect(res)
  end

  defp parse_scalar(query_result, cell) do
    Enum.at(cell, 1)
    # IO.puts("parse_row > query_result")
    # IO.inspect(query_result)
    # IO.puts("parse_row > cell")
    # IO.inspect(cell)
  end

  defp parse_node(query_result, cell) do
    [node_id | [label_indexes | [properties]]] = cell
    IO.puts("parse_node > cell")
    IO.inspect(cell)
    # [ id | [ labels | [ properties ]]] = value
    # labels = Enum.map(labels, fn label_id -> Map.get(all_labels, label_id) end)
    # properties = Enum.map(properties, fn [property_id | [_valueType | [value]]] -> {:"#{Map.get(all_propertyKeys, property_id)}", value} end) |> Map.new
    # node = %{id: id, labels: labels, properties: properties}
    # new(node)
    Node.new(%{
      id: node_id,
      labels: parse_labels(query_result, label_indexes),
      properties: parse_entity_properties(query_result, properties)
    })
  end

  defp parse_edge(query_result, cell) do
    [edge_id | [relation_index | [src_node_id | [dest_node_id | [properties]]]]] = cell

    Edge.new(%{
      id: edge_id,
      relation: get_relationship_type(query_result, relation_index),
      src_node: src_node_id,
      dest_node: dest_node_id,
      properties: parse_entity_properties(query_result, properties)
    })
  end

  defp parse_labels(query_result, label_indexes) do
    Enum.map(label_indexes, fn label_id -> Map.get(query_result.labels, label_id) end)
  end

  defp get_property_key(query_result, property_key_index) do
    Enum.at(query_result.property_keys, property_key_index)
  end

  defp get_relationship_type(query_result, relationship_type_index) do
    Map.get(query_result.relationship_types, relationship_type_index)
  end

  defp parse_entity_properties(query_result, properties) do
    IO.puts("parse_entity_properties")
    IO.inspect(properties)
    Enum.map(properties, fn [property_id | cell] -> {:"#{Map.get(query_result.property_keys, property_id)}", parse_cell(query_result, cell)} end) |> Enum.into(%{})
    # properties
    # |> Enum.at(0)
    # |> Enum.map(fn [property_key_index | value] ->
    #   {get_property_key(query_result, property_key_index), parse_scalar(query_result, value)}
    # end)
    # |> Enum.into(%{})
  end

  @doc "Transform a QueryResult into a list of maps as records."
  @spec results_to_maps(t()) :: list(map())
  def results_to_maps(%{header: header, result_set: records} = _query_result) do
    records
    |> Enum.map(fn record ->
      record
      |> Enum.with_index()
      |> Enum.map(fn {v, idx} -> {Enum.at(header, idx), v} end)
      |> Enum.into(%{})
    end)
  end

  @doc "Pretty print a QueryResult to a tabular string using `Scribe`."
  @spec pretty_print(t()) :: String.t()
  def pretty_print(%{header: header, result_set: records} = query_result) do
    if is_nil(header) or is_nil(records) do
      ""
    else
      Scribe.format(results_to_maps(query_result), data: header)
    end
  end

  defp get_stat(query_result, stat) do
    Map.get(query_result.statistics, stat, 0)
  end

  @doc "Get the `labels added` quantity from a QueryResult."
  @spec labels_added(t()) :: String.t()
  def labels_added(query_result) do
    get_stat(query_result, @labels_added)
  end

  @doc "Get the `nodes created` quantity from a QueryResult."
  @spec nodes_created(t()) :: String.t()
  def nodes_created(query_result) do
    get_stat(query_result, @nodes_created)
  end

  @doc "Get the `nodes deleted` quantity from a QueryResult."
  @spec nodes_deleted(t()) :: String.t()
  def nodes_deleted(query_result) do
    get_stat(query_result, @nodes_deleted)
  end

  @doc "Get the `properties set` quantity from a QueryResult."
  @spec properties_set(t()) :: String.t()
  def properties_set(query_result) do
    get_stat(query_result, @properties_set)
  end

  @doc "Get the `relationships created` quantity from a QueryResult."
  @spec relationships_created(t()) :: String.t()
  def relationships_created(query_result) do
    get_stat(query_result, @relationships_created)
  end

  @doc "Get the `relationships deleted` quantity from a QueryResult."
  @spec relationships_deleted(t()) :: String.t()
  def relationships_deleted(query_result) do
    get_stat(query_result, @relationships_deleted)
  end

  @doc "Get the `query internal execution time` (ms) from a QueryResult."
  @spec query_internal_execution_time(t()) :: String.t()
  def query_internal_execution_time(query_result) do
    get_stat(query_result, @query_internal_execution_time)
  end
end
