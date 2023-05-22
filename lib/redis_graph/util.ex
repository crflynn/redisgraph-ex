defmodule RedisGraph.Util do
  @moduledoc "Provides utility functions for RedisGraph modules."

  @doc """
  Generate a random string of characters `a-z` of length `n`.

  This is used to create a random alias for a node if one is not already set.
  """
  @spec random_string(pos_integer()) :: String.t()
  def random_string(n \\ 10) do
    1..n
    |> Enum.reduce("", fn _, acc -> acc <> to_string(Enum.take_random(?a..?z, 1)) end)
  end

  @doc """
  Surround a string with single quotes if not already.

  This is used to serialize strings when preparing redisgraph queries.
  If the passed value is not a string, it is returned unchanged
  """
  @spec quote_string(any()) :: any()
  def quote_string(v) when is_binary(v) do
    quote_if_not(v, 0) <> v <> quote_if_not(v, -1)
  end

  def quote_string(v) do
    v
  end

  defp quote_if_not(v, pos) do
    if String.at(v, pos) != "\'" do
      "\'"
    else
      ""
    end
  end

  def properties_to_string(properties) do
    props = cond do
      is_map(properties) and map_size(properties) > 0 -> Stream.map(properties, fn({k, x}) -> "#{k}: #{converted_value(x)}" end) |> Enum.join(", ")
      :true -> ""
    end
    IO.inspect(props)
    case String.length(props) do
      0 -> ""
      _ -> "{#{props}}"
    end
  end

  def labels_to_string(labels) do
    cond do
      is_list(labels) and length(labels) > 0 -> ":" <> Enum.join(labels, ":")
      :true -> ""
    end
  end

  def type_to_string(type) do # need to check if if can have multiple types
    cond do
      is_binary(type) and String.length(type) > 0 -> ":" <> type
      :true -> ""
    end
  end

  def converted_value(val) do
    IO.inspect(val)
    cond do
      is_binary(val) ->  "'" <> val <> "'"
      is_number(val) -> val
      is_boolean(val) -> "#{val}"
      is_nil(val) -> "null"
      true -> "value type is not supported"
    end
  end

end
