defmodule RedisGraph.Query do

  alias RedisGraph.Util
  alias RedisGraph.Node
  alias RedisGraph.Edge

  @accepted_operator_for_number %{
    equals: " = ",
    bigger: " > ",
    bigger_or_equal: " >= ",
    smaller: " < ",
    smaller_or_equal: " <= "
  }

  @accepted_operator_for_nil %{
    is: " IS ",
    is_not: " IS NOT "
  }

  @accepted_operator_for_binary %{
    equals: " = ",
    bigger: " > ",
    bigger_or_equal: " >= ",
    smaller: " < ",
    smaller_or_equal: " <= ",
    starts_with: " STARTS WITH ",
    ends_with: " ENDS WITH ",
    contains: " CONTAINS "
  }

  @accepted_operator_for_boolean %{
    equals: " = "
  }

  @accepted_operator_for_list %{
    in: " IN "
  }

  # defstruct [:id, :query]

  def new() do
    ""
  end

  def match(query) do
    " MATCH " <> query
  end

  def node(query, node) do
    query <> " (#{node.alias}#{Util.labels_to_string(node.labels)} #{Util.properties_to_string(node.properties)}) "
  end

  def edge(query, edge) do
    query <> " [#{edge.alias}#{Util.type_to_string(edge.type)} #{Util.properties_to_string(edge.properties)}] "
  end

  def return(query, values) when is_list(values) do
    converted_values = Stream.map(values, fn value ->
      cond do
        is_struct(value, Node) || is_struct(value, Edge) -> value.alias
        is_binary(value) -> value
        is_tuple(value) -> parse_tuple(value)
        true -> raise "incorrect value provided"
      end
    end) |> Enum.join(",")
    query <> " RETURN " <> converted_values
  end

  def return(query, value) when is_struct(value, Node) or is_struct(value, Edge) do
    query <> " RETURN " <> value.alias
  end

  def return(query, value) when is_binary(value) do
    query <> " RETURN " <> value
  end

  def return(query, {entity, _property_key} = value) when is_struct(entity, Node) or is_struct(entity, Edge) do
    query <> " RETURN " <> parse_tuple(value)
  end

  def return(_query, _) do
    raise "incorrect value provided"
  end

  defp parse_tuple({entity, property_key}) when is_binary(property_key) do
    entity.alias <> "." <> property_key
  end

  defp parse_tuple({entity, property_keys}) when is_list(property_keys) do
    Stream.map(property_keys, fn property_key -> entity.alias <> "." <> property_key end) |> Enum.join(",")
  end

  defp parse_list(values) do
    Stream.map(values, fn value ->
      cond do
        is_struct(value, Node) || is_struct(value, Edge) -> value.alias
        is_binary(value) -> value
        is_tuple(value) -> parse_tuple(value)
        true -> raise "incorrect value provided"
      end
    end) |> Enum.join(",")
  end

  # def order_by(query, {entity, _property_key} = value, asc \\ true) when is_tuple(value) and (is_struct(entity, Node) or is_struct(entity, Edge)) do
  #   order = if(asc, do: " ASC", else: " DESC ")
  #   query <> " ORDER BY " <> parse_tuple(value) <> order
  # end

  # def order_by(query, {function_name, entity} = value, asc) when is_tuple(value) and is_binary(function_name) and (is_struct(entity, Node) or is_struct(entity, Edge)) do
  #   order = if(asc, do: " ASC ", else: " DESC ")
  #   query <> " ORDER BY " <> "#{function_name}(#{entity.alias})" <> order
  # end

  def order_by(query, value, asc) when is_tuple(value) and tuple_size(value) == 2 do
    {entity, _property_key} = {function_name, entity_as_parameter} = value
    parsed_value = cond do
      is_struct(entity, Node) or is_struct(entity, Edge) -> parse_tuple(value)
      is_binary(function_name) and (is_struct(entity_as_parameter, Node) or is_struct(entity_as_parameter, Edge)) -> "#{function_name}(#{entity_as_parameter.alias})" # e.g. ORDER keys(n)
      true -> raise "incorrect value provided!"
    end
    order = if(asc, do: " ASC", else: " DESC ")
    query <> " ORDER BY " <> parsed_value <> order
  end

  def order_by(query, values, asc) when is_list(values) do # order_by(query, values, asc \\ true) doesnt work
    # error -- elixir def order_by/3 defines defaults multiple times. Elixir allows defaults to be declared once per definition.
    parsed_values = Enum.map(values, fn value ->
      {entity, _property_key} = {function_name, entity_as_parameter} = value
      cond do
        is_struct(entity, Node) or is_struct(entity, Edge) -> parse_tuple(value)
        is_binary(function_name) and (is_struct(entity_as_parameter, Node) or is_struct(entity_as_parameter, Edge)) -> "#{function_name}(#{entity_as_parameter.alias})" # e.g. ORDER keys(n)
        true -> raise "incorrect value provided!"
      end
    end)
    order = if(asc, do: " ASC", else: " DESC ")
    query <> " ORDER BY " <> parsed_values <> order
  end

  def where(query, {{entity, :property, value}, operator, element}) when (is_struct(entity, Node) or is_struct(entity, Edge)) and is_atom(operator) do
    parsed_left_element = if(not is_nil(Map.get(entity, String.to_atom(value))), do: "#{entity.alias}.#{value}", else: raise "provided property doesn't exist")
    parsed_tuple = cond do
      is_number(element) and (not is_nil(Map.get(@accepted_operator_for_number, operator))) -> parsed_left_element <> Map.get(@accepted_operator_for_number, operator) <> "#{Util.converted_value(element)}"
      is_binary(element) and (not is_nil(Map.get(@accepted_operator_for_binary, operator))) -> parsed_left_element <> Map.get(@accepted_operator_for_binary, operator) <> "#{Util.converted_value(element)}"
      is_nil(element) and (not is_nil(Map.get(@accepted_operator_for_nil, operator))) -> parsed_left_element <> Map.get(@accepted_operator_for_nil, operator) <> "#{Util.converted_value(element)}"
      is_boolean(element) and (not is_nil(Map.get(@accepted_operator_for_boolean, operator))) -> parsed_left_element <> Map.get(@accepted_operator_for_boolean, operator) <> "#{Util.converted_value(element)}"
      is_list(element) and (not is_nil(Map.get(@accepted_operator_for_list, operator))) -> parsed_left_element <> Map.get(@accepted_operator_for_list, operator) <> "[#{List.flatten(element) |> Stream.map(fn n -> Util.converted_value(n) end) |> Enum.join(",")}]"
    end
    query <> " WHERE " <> parsed_tuple
  end

  def where(query, {entity, :label, value}) when (is_struct(entity, Node) or is_struct(entity, Edge)) and is_binary(value) do
    parameter = if(not is_nil(Enum.find_index(entity.labels, fn label -> label == value end)), do: "#{entity.alias}:#{value}", else: raise "provided label doesn't exist")
    query <> " WHERE " <> parameter
  end

  def where(query, {entity, :type, value}) when (is_struct(entity, Node) or is_struct(entity, Edge)) and is_binary(value) do
    parameter = if(not is_nil(if(entity.type == value, do: value, else: nil)), do: "#{entity.alias}:#{value}", else: raise "provided type doesn't exist")
    query <> " WHERE " <> parameter
  end


  def from_through_to(query, node, edge, node) do
    query
  end

end
