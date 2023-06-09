defmodule RedisGraph.Util do

  @spec random_string(pos_integer()) :: String.t()
  def random_string(n \\ 10) do
    1..n
    |> Enum.reduce("", fn _, acc -> acc <> to_string(Enum.take_random(?a..?z, 1)) end)
  end

  @spec properties_to_string(map() | any()) :: String.t()
  def properties_to_string(properties) do
    props =
      cond do
        is_map(properties) and map_size(properties) > 0 ->
          Stream.map(properties, fn {k, x} -> "#{k}: #{value_to_string(x)}" end)
          |> Enum.join(", ")
        true ->
          ""
      end

    case String.length(props) do
      0 -> ""
      _ -> " {#{props}}"
    end
  end

  @spec labels_to_string(list(String.t()) | any()) :: String.t()
  def labels_to_string(labels) do
    cond do
      is_list(labels) and length(labels) > 0 -> ":" <> Enum.join(labels, ":")
      true -> ""
    end
  end

  @spec type_to_string(list(String.t()) | any()) :: String.t()
  def type_to_string(type) do
    cond do
      is_binary(type) and String.length(type) > 0 -> ":" <> type
      true -> ""
    end
  end

  @spec value_to_string(any()) :: String.t()
  def value_to_string(val) do
    cond do
      # check if string contains function
      is_binary(val) and String.contains?(val, "(") and String.contains?(val, ")") -> val
      is_binary(val) and String.length(val) > 0 -> "'" <> val <> "'"
      is_number(val) -> "#{val}"
      is_boolean(val) -> "#{val}"
      is_nil(val) -> "null"
      is_atom(val) -> Atom.to_string(val)
      is_list(val) -> "[#{Stream.map(val, fn individual_value -> value_to_string(individual_value) end) |> Enum.join(", ")}]"
      is_map(val) -> "{#{Stream.map(val, fn {k, x} -> "#{k}: #{value_to_string(x)}" end)  |> Enum.join(", ")}}"
      true -> "#{val}"
    end

  end

end
