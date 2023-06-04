defmodule RedisGraph.QueryBuilder do

  alias RedisGraph.{Node, Edge, Util, Query}

  @spec build_query(Query.t()) :: {:ok, String.t()} | {:error, String.t()}
  def build_query(%{error: nil} = context) do
    %{used_clauses_with_data: used_clauses_with_data} = context
    query_list =
      Stream.map(used_clauses_with_data, fn used_clause_with_data ->
        %{clause: clause, elements: elements} = used_clause_with_data

        case clause do
          :create -> build_query_for_general_clause(context, clause, elements)
          :match -> build_query_for_general_clause(context, clause, elements)
          :optional_match -> build_query_for_general_clause(context, clause, elements)
          :merge -> build_query_for_general_clause(context, clause, elements)
          :delete -> build_query_for_delete_clause(context, elements)
          :set -> build_query_for_set_clause(context, clause, elements)
          :on_match_set -> build_query_for_set_clause(context, clause, elements)
          :on_create_set -> build_query_for_set_clause(context, clause, elements)
          :with -> build_query_for_with_clause(context, elements)
          :where -> build_query_for_where_clause(context, elements)
          :order_by -> build_query_for_order_by_clause(context, elements)
          :limit -> build_query_for_limit_clause(context, elements)
          :skip -> build_query_for_skip_clause(context, elements)
          :return -> build_query_for_return_clause(context, clause, elements)
          :return_distinct -> build_query_for_return_clause(context, clause, elements)
          # add error in context and call build_query()?
          _ -> "!!!Provided clause -- #{clause} is not yet supported!!!"
        end
      end)

    final_query = Enum.join(query_list, " ")
    {:ok, final_query}
  end

  def build_query(context) do
    %{error: error} = context
    {:error, error}
  end

  @spec build_query_for_general_clause(Query.t(), atom(), list(map())) :: String.t()
  defp build_query_for_general_clause(context, clause, elements) do
    {_last_element, query} =
      Enum.reduce(elements, {nil, ""}, fn element_alias, acc ->
        {last_element, query} = acc
        node = Map.get(context, :nodes, %{}) |> Map.get(element_alias, nil)
        edge = Map.get(context, :edges, %{}) |> Map.get(element_alias, nil)

        cond do
          is_struct(node, Node) and is_struct(last_element, Node) ->
            last_element = node

            query =
              query <>
                ",(#{Util.converted_value(node.alias)}#{Util.labels_to_string(node.labels)}#{Util.properties_to_string(node.properties)})"

            {last_element, query}

          is_struct(node, Node) ->
            last_element = node

            query =
              query <>
                "(#{Util.converted_value(node.alias)}#{Util.labels_to_string(node.labels)}#{Util.properties_to_string(node.properties)})"

            {last_element, query}

          is_struct(edge, Edge) and is_struct(last_element, Node) and
              edge.src_node.alias == last_element.alias ->
            last_element = edge

            query =
              query <>
                "-[#{Util.converted_value(edge.alias)}#{Util.type_to_string(edge.type)}#{Util.properties_to_string(edge.properties)}]->"

            {last_element, query}

          is_struct(edge, Edge) and is_struct(last_element, Node) and
              edge.dest_node.alias == last_element.alias ->
            last_element = edge

            query =
              query <>
                "<-[#{Util.converted_value(edge.alias)}#{Util.type_to_string(edge.type)}#{Util.properties_to_string(edge.properties)}]-"

            {last_element, query}

          true ->
            last_element = nil
            query = query <> "!!!something went wrong, check the query!!!"
            {last_element, query}
        end
      end)

    clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()
    "#{clause_to_string} #{query}"
  end

  @spec build_query_for_where_clause(Query.t(), list(map())) :: String.t()
  defp build_query_for_where_clause(_context, elements) do
    query_list =
      Stream.map(elements, fn element ->
        %{logical_operator: logical_operator, elements: elements_per_logical_operator} = element

        logical_operator_to_string =
          if(logical_operator == :none,
            do: "",
            else:
              (Atom.to_string(logical_operator) |> String.replace("_", " ") |> String.upcase()) <>
                " "
          )

        inner_query_list =
          Stream.map(elements_per_logical_operator, fn element_per_logical_operator ->
            %{alias: alias, property: property, operator: operator, value: value} =
              element_per_logical_operator

            "#{logical_operator_to_string}#{Util.converted_value(alias)}.#{property} #{operator} #{Util.converted_value(value)}"
          end)

        Enum.join(inner_query_list, " ")
      end)

    query_list_joined = Enum.join(query_list, " ")
    "WHERE #{query_list_joined}"
  end

  @spec build_query_for_return_clause(Query.t(), atom(), list(map())) :: String.t()
  defp build_query_for_return_clause(_context, clause, elements) do
    clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()
    query_list =
      Stream.map(elements, fn element ->
        %{alias: alias, property: property, function: function, as: as} = element

        cond do
          not is_nil(alias) and not is_nil(property) and not is_nil(function) and not is_nil(as) ->
            "#{function}(#{Util.converted_value(alias)}.#{property}) AS #{as}"

          not is_nil(alias) and not is_nil(property) and not is_nil(function) ->
            "#{function}(#{Util.converted_value(alias)}.#{property})"

          not is_nil(alias) and not is_nil(function) and not is_nil(as) ->
            "#{function}(#{Util.converted_value(alias)}) AS #{as}"

          not is_nil(alias) and not is_nil(function) ->
            "#{function}(#{Util.converted_value(alias)})"

          not is_nil(alias) and not is_nil(property) and not is_nil(as) ->
            "#{Util.converted_value(alias)}.#{property} AS #{as}"

          not is_nil(alias) and not is_nil(property) ->
            "#{Util.converted_value(alias)}.#{property}"

          not is_nil(alias) and not is_nil(as) ->
            "#{Util.converted_value(alias)} AS #{as}"

          not is_nil(alias) ->
            "#{Util.converted_value(alias)}"

          true ->
            "Wrong parameters provided to return function"
        end
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "#{clause_to_string} #{query_list_joined}"
  end

  @spec build_query_for_order_by_clause(Query.t(), list(map())) :: String.t()
  defp build_query_for_order_by_clause(_context, elements) do
    query_list =
      Stream.map(elements, fn element ->
        %{property: property, alias: alias, order: order} = element
        "#{Util.converted_value(alias)}.#{property} #{order}"
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "ORDER BY #{query_list_joined}"
  end

  @spec build_query_for_with_clause(Query.t(), list(map())) :: String.t()
  defp build_query_for_with_clause(_context, elements) do
    query_list =
      Stream.map(elements, fn element ->
        %{alias: alias, property: property, function: function, as: as} = element

        cond do
          not is_nil(alias) and not is_nil(property) and not is_nil(function) and not is_nil(as) ->
            "#{function}(#{Util.converted_value(alias)}.#{property}) AS #{as}"

          not is_nil(alias) and not is_nil(property) and not is_nil(function) ->
            "#{function}(#{Util.converted_value(alias)}.#{property})"

          not is_nil(alias) and not is_nil(function) and not is_nil(as) ->
            "#{function}(#{Util.converted_value(alias)}) AS #{as}"

          not is_nil(alias) and not is_nil(function) ->
            "#{function}(#{Util.converted_value(alias)})"

          not is_nil(alias) and not is_nil(property) and not is_nil(as) ->
            "#{Util.converted_value(alias)}.#{property} AS #{as}"

          not is_nil(alias) and not is_nil(property) ->
            "#{Util.converted_value(alias)}.#{property}"

          not is_nil(alias) and not is_nil(as) ->
            "#{Util.converted_value(alias)} AS #{as}"

          not is_nil(alias) ->
            "#{Util.converted_value(alias)}"

          true ->
            "Wrong parameters provided to with function"
        end
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "WITH #{query_list_joined}"
  end

  @spec build_query_for_set_clause(Query.t(), atom(), list(map())) :: String.t()
  defp build_query_for_set_clause(_context, clause, elements) do
    clause_to_string =
      if(clause == :set,
        do: "SET",
        else:
          (Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase())
      )
    query_list =
      Stream.map(elements, fn element ->
        %{alias: alias, property: property, operator: operator, value: value} = element
        "#{Util.converted_value(alias)} #{operator} #{Util.converted_value(value)}"
        cond do
          not is_nil(alias) and not is_nil(property) ->
            "#{Util.converted_value(alias)}.#{property} #{operator} #{Util.converted_value(value)}"
          not is_nil(alias) ->
            "#{Util.converted_value(alias)} #{operator} #{Util.converted_value(value)}"
          true ->
            "Wrong parameters provided to with function"
        end
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "#{clause_to_string} #{query_list_joined}"
  end

  defp build_query_for_on_match_set_clause(_context, elements) do
    query_list =
      Stream.map(elements, fn element ->
        %{alias: alias, property: property, operator: operator, value: value} = element
        "#{Util.converted_value(alias)} #{operator} #{Util.converted_value(value)}"
        cond do
          is_atom(alias) and is_binary(property) ->
            "#{Util.converted_value(alias)}.#{property} #{operator} #{Util.converted_value(value)}"
          is_atom(alias) ->
            "#{Util.converted_value(alias)} #{operator} #{Util.converted_value(value)}"
          true ->
            "Wrong parameters provided to with function"
        end
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "ON MATCH SET #{query_list_joined}"
  end

  defp build_query_for_on_create_set_clause(_context, elements) do
    query_list =
      Stream.map(elements, fn element ->
        %{alias: alias, property: property, operator: operator, value: value} = element
        "#{Util.converted_value(alias)} #{operator} #{Util.converted_value(value)}"
        cond do
          is_atom(alias) and is_binary(property) ->
            "#{Util.converted_value(alias)}.#{property} #{operator} #{Util.converted_value(value)}"
          is_atom(alias) ->
            "#{Util.converted_value(alias)} #{operator} #{Util.converted_value(value)}"
          true ->
            "Wrong parameters provided to with function"
        end
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "ON CREATE SET #{query_list_joined}"
  end

  @spec build_query_for_delete_clause(Query.t(), list(map())) :: String.t()
  defp build_query_for_delete_clause(_context, elements) do
    query_list = Enum.join(elements, ", ")
    "DELETE #{query_list}"
  end

  @spec build_query_for_limit_clause(Query.t(), list(map())) :: String.t()
  defp build_query_for_limit_clause(_context, elements) do
    query_list = Enum.map(elements, fn element -> "LIMIT #{element}" end)
    Enum.join(query_list, " ")
  end

  @spec build_query_for_skip_clause(Query.t(), list(map())) :: String.t()
  defp build_query_for_skip_clause(_context, elements) do
    query_list = Enum.map(elements, fn element -> "SKIP #{element}" end)
    Enum.join(query_list, " ")
  end
end
