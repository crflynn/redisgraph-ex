defmodule RedisGraph.QueryResult do
  @labels_added "Labels added"
  @nodes_created "Nodes created"
  @nodes_deleted "Nodes deleted"
  @relationships_deleted "Relationships deleted"
  @properties_set "Properties set"
  @relationships_created "Relationships created"
  @internal_execution_time "Query internal execution time"

  @enforce_keys [:graph, :raw_result_set]
  defstruct [:graph, :raw_result_set, :header, :result_set, :statistics]

  def new(map) do
    s = struct(__MODULE__, map)

    if length(Enum.at(s.raw_result_set, 0)) == 0 do
      %{s | statistics: parse_statistics(Enum.at(s.raw_result_set, -1))}
    else
      %{
        parse_results(s)
        | statistics: parse_statistics(Enum.at(s.raw_result_set, -1))
      }
    end
  end

  def is_empty(query_result) do
    if is_nil(query_result.result_set) or length(query_result.result_set) == 0 do
      true
    else
      false
    end
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

  def parse_results(%{raw_result_set: [[header | records] | _statistics]} = query_result) do
    if length(header) > 0 do
      %{
        query_result
        | header: header,
          result_set: records
      }
    else
      query_result
    end
  end

  def pretty_print(%{header: header, result_set: records}) do
    if is_nil(header) or is_nil(records) do
      ""
    else
      maps =
        records
        |> Enum.map(fn r ->
          r
          |> Enum.with_index()
          |> Enum.map(fn {v, idx} -> {Enum.at(header, idx), v} end)
          |> Enum.into(%{})
        end)

      Scribe.format(maps)
    end
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
