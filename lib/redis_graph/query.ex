defmodule RedisGraph.Query do
  alias RedisGraph.{Edge, QueryBuilder}

  @type clauses() :: :create | :match | :optional_match | :merge | :delete | :set | :on_match_set | :on_create_set | :with | :where | :order_by | :limit | :skip | :return
  @type t() :: %__MODULE__{
          current_clause: clauses() | nil,
          last_element: RedisGraph.Node.t() | RedisGraph.Edge.t() | where_t() | nil,
          error: String.t() | nil,
          nodes: %{atom() => RedisGraph.Node.t()},
          edges: %{atom() => RedisGraph.Edge.t()},
          variables: [String.t()],
          used_clauses: [[atom()]] | [],
          used_clauses_with_data: [[map()]] | []
        }

  @type where_t() :: %{
          alias: atom(),
          key: String.t(),
          operator: String.t(),
          value:
            String.t()
            | number()
            | boolean()
            | nil
            | list(String.t() | number() | boolean() | nil)
            | map()
        }

  @type accepted_operator_in_where_clause() ::
          :equals
          | :not_equal
          | :bigger
          | :bigger_or_equal
          | :smaller
          | :smaller_or_equal
          | :starts_with
          | :ends_with
          | :contains
          | :in

  @type accepted_value() ::
          String.t() | number() | boolean() | nil | list(String.t() | number() | boolean() | nil | map()) | map()

  @accepted_operator_to_string_in_where_clause %{
    equals: "=",
    not_equal: "<>",
    bigger: ">",
    bigger_or_equal: ">=",
    smaller: "<",
    smaller_or_equal: "<=",
    starts_with: "STARTS WITH",
    ends_with: "ENDS WITH",
    contains: "CONTAINS",
    in: "IN"
  }

  @accepted_operator_for_number_in_where_clause [
    :equals,
    :not_equal,
    :bigger,
    :bigger_or_equal,
    :smaller,
    :smaller_or_equal
  ]

  @accepted_operator_for_nil_in_where_clause [:equals, :not_equal]

  @accepted_operator_for_binary_in_where_clause [
    :equals,
    :not_equal,
    :bigger,
    :bigger_or_equal,
    :smaller,
    :smaller_or_equal,
    :starts_with,
    :ends_with,
    :contains
  ]

  @accepted_operator_for_boolean_in_where_clause [:equals]

  @accepted_operator_for_list_in_where_clause [:in]

  defstruct [
    :current_clause,
    :last_element,
    error: nil,
    nodes: %{},
    edges: %{},
    variables: [],
    used_clauses: [],
    used_clauses_with_data: []
  ]

  def new() do
    struct(__MODULE__)
  end

  @spec match(t()) :: t()
  def match(%{error: nil} = context) do
    context = add_clause_if_not_present(context, :match)
    context = check_if_return_clause_already_provided(context, :match)
    Map.put(context, :current_clause, :match)
  end

  def match(context) do
    context
  end

  @spec optional_match(t()) :: t()
  def optional_match(%{error: nil} = context) do
    context = add_clause_if_not_present(context, :optional_match)
    context = check_if_return_clause_already_provided(context, :optional_match)
    Map.put(context, :current_clause, :optional_match)
  end

  def optional_match(context) do
    context
  end

  @spec merge(t()) :: t()
  def merge(%{error: nil} = context) do
    context = add_clause_if_not_present(context, :merge)
    context = check_if_return_clause_already_provided(context, :merge)
    Map.put(context, :current_clause, :merge)
  end

  def merge(context) do
    context
  end

  @spec create(t()) :: t()
  def create(%{error: nil} = context) do
    context = add_clause_if_not_present(context, :create)
    context = check_if_return_clause_already_provided(context, :create)
    Map.put(context, :current_clause, :create)
  end

  def create(context) do
    context
  end


  @spec delete(t(), atom()) :: t()
  def delete(%{error: nil} = context, alias) do
    current_clause = Map.get(context, :current_clause)
    context =
      if current_clause != :delete do
        context = add_clause_if_not_present(context, :delete)
        Map.put(context, :current_clause, :delete)
      else
        context
      end
    context = check_if_provided_alias_present(context, alias)
    context = check_if_match_ends_with_relationship(context)

    %{error: error} = context

    case error do
      nil ->
        context = update_used_clauses_with_data(context, alias)
        context = Map.put(context, :current_clause, :delete)
        context
      _ ->
        context
    end
  end

  def delete(context, _alias) do
    context
  end

  @spec node(t(), atom(), list(String.t())) :: t()
  def node(context, alias, labels) when is_list(labels) do
    node(context, alias, labels, %{})
  end

  @spec node(t(), atom(), map()) :: t()
  def node(context, alias, properties) when is_map(properties) do
    node(context, alias, [], properties)
  end

  @spec node(t(), atom(), list(String.t()), map()) :: t()
  def node(context, alias, labels \\ [], properties \\ %{})

  def node(context = %{error: nil}, alias, labels, properties) do
    node = RedisGraph.Node.new(%{alias: alias, labels: labels, properties: properties})
    last_element = Map.get(context, :last_element)

    context =
      if(is_struct(last_element, Edge)) do
        alias = Map.get(last_element, :alias)
        dest_node = Map.get(last_element, :dest_node)

        new_edge =
          if(is_nil(dest_node)) do
            Map.put(last_element, :dest_node, node)
          else
            Map.put(last_element, :src_node, node)
          end

        {_old_value, updated_context} =
          Map.get_and_update(context, :edges, fn edges ->
            {edges, Map.put(edges, alias, new_edge)}
          end)

        updated_context
      else
        context
      end

    {_old_value, context} =
      Map.get_and_update(context, :nodes, fn old_map ->
        {old_map, Map.put(old_map, alias, node)}
      end)

    context = update_used_clauses_with_data(context, alias)
    context = Map.put(context, :last_element, node)
    context
  end

  def node(context, _alias, _labels, _properties) do
    context
  end

  @spec relationship_from_to(t(), atom(), String.t(), map()) :: t()
  def relationship_from_to(context, alias, type \\ "", properties \\ %{})

  def relationship_from_to(%{error: nil} = context, alias, type, properties) do
    last_element = Map.get(context, :last_element)

    context =
      if(is_nil(last_element)) do
        Map.put(
          context,
          :error,
          "Relationship has to originate from a Node. Add a Node first with node() function"
        )
      else
        context
      end

    context =
      if(is_struct(last_element, Edge)) do
        Map.put(
          context,
          :error,
          "You cannot have multiple Relationships in a row. Add a Node between them with node() function"
        )
      else
        context
      end

    error = Map.get(context, :error)

    case error do
      nil ->
        edge =
          RedisGraph.Edge.new(%{
            alias: alias,
            type: type,
            properties: properties,
            src_node: last_element
          })

        {_old_value, context} =
          Map.get_and_update(context, :edges, fn old_map ->
            {old_map, Map.put(old_map, alias, edge)}
          end)

        context = update_used_clauses_with_data(context, alias)
        context = Map.put(context, :last_element, edge)
        context

      _ ->
        context
    end
  end

  def relationship_from_to(context, _alias, _type, _properties) do
    context
  end

  @spec relationship_to_from(t(), atom(), String.t(), map()) :: t()
  def relationship_to_from(context, alias, type \\ "", properties \\ %{})

  def relationship_to_from(%{error: nil} = context, alias, type, properties) do
    last_element = Map.get(context, :last_element)

    context =
      if(is_nil(last_element)) do
        Map.put(
          context,
          :error,
          "Relationship has to point to a Node. Add a Node first with node() function"
        )
      else
        context
      end

    context =
      if(is_struct(last_element, Edge)) do
        Map.put(
          context,
          :error,
          "You cannot have multiple Relationships in a row. Add a Node between them with node() function"
        )
      else
        context
      end

    error = Map.get(context, :error)

    case error do
      nil ->
        edge =
          RedisGraph.Edge.new(%{
            alias: alias,
            type: type,
            properties: properties,
            dest_node: last_element
          })

        {_old_value, context} =
          Map.get_and_update(context, :edges, fn old_map ->
            {old_map, Map.put(old_map, alias, edge)}
          end)

        context = update_used_clauses_with_data(context, alias)
        context = Map.put(context, :last_element, edge)
        context

      _ ->
        context
    end
  end

  def relationship_to_from(context, _alias, _type, _properties) do
    context
  end

  @spec where(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          accepted_value()
        ) :: t()
  def where(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :none)
  end

  defp where(%{error: nil} = context, _alias, "", _operator, _value, _logical_operator) do
    Map.put(context, :error, "Provide property name. E.g. new() |> match() |> node(\"n\") |> where({\"n\", \"age\", \">\", 20}) |> return(\"n\") |> ...")
  end

  defp where(%{error: nil} = context, alias, property, operator, value, logical_operator) do
    # check if where clause with :none or :not exists and in that case not give error
    # where or where_not put as first element and rest should be after it. where/where_not can be only once and after that only and/or func can be used
    current_clause = Map.get(context, :current_clause)

    context =
      if current_clause != :where do
        context = add_clause_if_not_present(context, :where)
        Map.put(context, :current_clause, :where)
      else
        context
      end

    elements_size =
      Map.get(context, :used_clauses_with_data, [])
      |> List.last(%{})
      |> Map.get(:elements, [])
      |> length()

    cond do
      (logical_operator == :and or logical_operator == :or or logical_operator == :xor) and
          elements_size == 0 ->
        Map.put(
          context,
          :error,
          "Only where/2 and where_not/2 with as the first WHERE clause with a single component is accepted"
        )

      (logical_operator == :and_not or logical_operator == :or_not or logical_operator == :xor_not) and
          elements_size == 0 ->
        Map.put(
          context,
          :error,
          "Only where/2 and where_not/2 with as the first WHERE clause with a single component is accepted"
        )

      true ->
        context = check_if_provided_alias_present(context, alias)
        context = check_if_match_ends_with_relationship(context)
        context = check_if_match_clause_provided(context, :where)

        %{error: error} = context

        case error do
          nil ->
            content = %{
              alias: alias,
              property: property,
              operator: Map.get(@accepted_operator_to_string_in_where_clause, operator),
              value: value
            }

            where_clause =
              cond do
                is_number(value) &&
                    Enum.member?(@accepted_operator_for_number_in_where_clause, operator) ->
                  [content]

                is_binary(value) &&
                    Enum.member?(@accepted_operator_for_binary_in_where_clause, operator) ->
                  [content]

                is_nil(value) &&
                    Enum.member?(@accepted_operator_for_nil_in_where_clause, operator) ->
                  [content]

                is_boolean(value) &&
                    Enum.member?(@accepted_operator_for_boolean_in_where_clause, operator) ->
                  [content]

                is_list(value) &&
                    Enum.member?(@accepted_operator_for_list_in_where_clause, operator) ->
                  [content]

                true ->
                  Map.put(context, :error, true)

                  raise "Provided value: \"#{value}\" or/and operator: \"#{operator}\" in the WHERE clause is not supported with the given operator."
              end

            where_element = %{logical_operator: logical_operator, elements: where_clause}
            context = update_used_clauses_with_data(context, where_element)
            context = Map.put(context, :current_clause, :where)
            context

          _ ->
            context
        end
    end
  end

  defp where(context, _alias, _property, _operator, _value, _logical_operator) do
    context
  end

  @spec where_not(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          String.t() | number() | boolean() | list() | nil
        ) :: t()
  def where_not(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :not)
  end

  @spec or_where(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          String.t() | number() | boolean() | list() | nil
        ) :: t()
  def or_where(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :or)
  end

  @spec and_where(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          String.t() | number() | boolean() | list() | nil
        ) :: t()
  def and_where(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :and)
  end

  @spec xor_where(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          String.t() | number() | boolean() | list() | nil
        ) :: t()
  def xor_where(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :xor)
  end

  @spec and_not_where(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          String.t() | number() | boolean() | list() | nil
        ) :: t()
  def and_not_where(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :and_not)
  end

  @spec or_not_where(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          String.t() | number() | boolean() | list() | nil
        ) :: t()
  def or_not_where(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :or_not)
  end

  @spec xor_not_where(
          t(),
          atom(),
          String.t(),
          accepted_operator_in_where_clause(),
          String.t() | number() | boolean() | list() | nil
        ) :: t()
  def xor_not_where(context, alias, property, operator, value) do
    where(context, alias, property, operator, value, :xor_not)
  end

  @spec order_by(t(), atom(), String.t(), boolean()) :: t()
  def order_by(context, alias, property, asc \\ true)

  def order_by(%{error: nil} = context, _alias, "", _asc) do
    Map.put(context, :error, "Provide property name. E.g. new() |> match() |> node(\"n\") |> order_by(\"n\", \"age\") |> return(\"n\") |> ...")
  end

  def order_by(%{error: nil} = context, alias, property, asc) do
    current_clause = Map.get(context, :current_clause)

    context =
      if current_clause != :order_by do
        context = add_clause_if_not_present(context, :order_by)
        Map.put(context, :current_clause, :order_by)
      else
        context
      end
    context = check_if_provided_alias_present(context, alias)
    context = check_if_match_ends_with_relationship(context)
    context = check_if_match_clause_provided(context, :order_by)

    %{error: error} = context

    case error do
      nil ->
        order = if(asc, do: "ASC", else: "DESC")
        order_by_element = %{alias: alias, property: property, order: order}
        context = update_used_clauses_with_data(context, order_by_element)
        context = Map.put(context, :current_clause, :order_by)
        context

      _ ->
        context
    end
  end

  def order_by(context, _alias, _property, _asc) do
    context
  end

  @spec limit(t(), non_neg_integer()) :: t()
  def limit(%{error: nil} = context, value) do
    current_clause = Map.get(context, :current_clause)

    context =
      if current_clause != :limit do
        context = add_clause_if_not_present(context, :limit)
        Map.put(context, :current_clause, :limit)
      else
        context
      end

    context = check_if_match_clause_provided(context, :limit)

    %{error: error} = context

    case error do
      nil ->
        context = update_used_clauses_with_data(context, value)
        context = Map.put(context, :current_clause, :limit)
        context

      _ ->
        context
    end
  end

  def limit(context, _value) do
    context
  end

  @spec skip(t(), non_neg_integer()) :: t()
  def skip(%{error: nil} = context, value) do
    current_clause = Map.get(context, :current_clause)

    context =
      if current_clause != :skip do
        context = add_clause_if_not_present(context, :skip)
        Map.put(context, :current_clause, :skip)
      else
        context
      end

    context = check_if_match_ends_with_relationship(context)
    context = check_if_match_clause_provided(context, :skip)

    %{error: error} = context

    case error do
      nil ->
        context = update_used_clauses_with_data(context, value)
        context = Map.put(context, :current_clause, :skip)
        context

      _ ->
        context
    end
  end

  def skip(context, _value) do
    context
  end

  @spec return(t(), atom(), String.t() | nil) :: t()
  def return(context, alias, as \\ nil) do
    return_function_and_property(context, nil, alias, nil, as, false)
  end

  @spec return_property(t(), atom(), String.t(), String.t() | nil) :: t()
  def return_property(context, alias, property, as \\ nil) do
    return_function_and_property(context, nil, alias, property, as, false)
  end

  @spec return_function(t(), String.t(), atom(), String.t() | nil) :: t()
  def return_function(context, function, alias, as \\ nil) do
    return_function_and_property(context, function, alias, nil, as, false)
  end

  @spec return_function_and_property(t(), String.t(), atom(), String.t(), String.t() | nil) :: t()
  def return_function_and_property(context, function, alias, property, as \\ nil) do
    return_function_and_property(context, function, alias, property, as, false)
  end

  @spec return_distinct(t(), atom(), String.t() | nil) :: t()
  def return_distinct(context, alias, as \\ nil) do
    return_function_and_property(context, nil, alias, nil, as, true)
  end

  @spec return_distinct_property(t(), atom(), String.t(), String.t() | nil) :: t()
  def return_distinct_property(context, alias, property, as \\ nil) do
    return_function_and_property(context, nil, alias, property, as, true)
  end

  @spec return_distinct_function(t(), String.t(), atom(), String.t() | nil) :: t()
  def return_distinct_function(context, function, alias, as \\ nil) do
    return_function_and_property(context, function, alias, nil, as, true)
  end

  @spec return_distinct_function_and_property(t(), String.t(), atom(), String.t(), String.t() | nil) :: t()
  def return_distinct_function_and_property(context, function, alias, property, as \\ nil) do
    return_function_and_property(context, function, alias, property, as, true)
  end

  @spec return_function_and_property(
          t(),
          String.t() | nil,
          atom(),
          String.t() | nil,
          String.t() | nil,
          boolean()
        ) :: t()
  defp return_function_and_property(%{error: nil} = context, "", _alias, _property, _asc, _distinct) do
    Map.put(context, :error, "Provide function name. E.g. new() |> match() |> node(\"n\") |> return(\"toUpper\", \"n\", \"age\") |> ...")
  end

  defp return_function_and_property(%{error: nil} = context, _function, _alias, "", _asc, _distinct) do
    Map.put(context, :error, "Provide property name. E.g. new() |> match() |> node(\"n\") |> return(\"toUpper\", \"n\", \"age\") |> ...")
  end

  defp return_function_and_property(%{error: nil} = context, function, alias, property, as, distinct) do
    clause = if(distinct == false, do: :return, else: :return_distinct)
    current_clause = Map.get(context, :current_clause)
    context =
      if current_clause != clause do
        context = add_clause_if_not_present(context, clause)
        Map.put(context, :current_clause, clause)
      else
        context
      end
    context = check_if_provided_alias_present(context, alias)
    context = check_if_match_ends_with_relationship(context)
    match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:match)
    optional_match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:optional_match)
    create_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:create)
    merge_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:merge)
    context =
      if((not match_clause_present?) and (not create_clause_present?) and (not merge_clause_present?) and  (not optional_match_clause_present?)) do
        Map.put(
          context,
          :error,
          "One of these clauses MATCH, CREATE, MERGE etc. has to be provided first before using RETURN. E.g. new() |> match() |> node(\"n\") |> return(\"n\")  |> ..."
        )
      else
        context
      end

    %{error: error} = context

    case error do
      nil ->
        return_element = %{alias: alias, property: property, function: function, as: as}
        context = update_used_clauses_with_data(context, return_element)
        context = Map.put(context, :current_clause, clause)
        context

      _ ->
        context
    end
  end

  defp return_function_and_property(context, _function, _alias, _property, _as,  _distinct) do
    context
  end

  @spec with(t(), atom(), String.t() | nil) :: t()
  def with(context, alias, as \\ nil) do
    with_function_and_property(context, nil, alias, nil, as)
  end

  @spec with_property(t(), atom(), String.t(), String.t() | nil) :: t()
  def with_property(context, alias, property, as \\ nil) do
    with_function_and_property(context, nil, alias, property, as)
  end

  @spec with_function(t(), String.t(), atom(), String.t() | nil) :: t()
  def with_function(context, function, alias, as \\ nil) do
    with_function_and_property(context, function, alias, nil, as)
  end

  def with_function_and_property(context, function, alias, property, as \\ nil)

  @spec with_function_and_property(
          t(),
          String.t() | nil,
          atom(),
          String.t() | nil,
          String.t() | nil
        ) :: t()

  def with_function_and_property(%{error: nil} = context, "", _alias, _property, _as) do
    Map.put(context, :error, "Provide function name. E.g. new() |> match() |> node(\"n\") |> with(\"toUpper\", \"n\", \"name\", \"Name\") |> return(\"Name\") |>...")
  end

  def with_function_and_property(%{error: nil} = context, _function, _alias, "", _as) do
    Map.put(context, :error, "Provide property name. E.g. new() |> match() |> node(\"n\") |> with(\"toUpper\", \"n\", \"name\", \"Name\") |> return(\"Name\") |> ...")
  end

  def with_function_and_property(%{error: nil} = context, function, alias, property, as) do
    # add the variables from AS NewVariable into another map
    current_clause = Map.get(context, :current_clause)

    context =
      if current_clause != :with do
        context = add_clause_if_not_present(context, :with)
        Map.put(context, :current_clause, :with)
      else
        context
      end

    # %{error: error} = context
    provided_wildcard? = alias == "*"
    variable_present? = Map.get(context, :variables, []) |> Enum.member?(alias)
    alias_present? =
      Map.get(context, :edges, %{}) |> Map.has_key?(alias) or
        Map.get(context, :nodes, %{}) |> Map.has_key?(alias)
    context =
      if((not provided_wildcard?) and (not alias_present?) and (not variable_present?)) do
        Map.put(
          context,
          :error,
          "Provided alias: \"#{alias}\" was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(\"n\") |> with(\"n\", \"Node\") |> |> return(\"n\") ..."
        )
      else
        context
      end
    context = check_if_match_ends_with_relationship(context)
    context = check_if_match_clause_provided(context, :with)

    %{error: error} = context

    case error do
      nil ->
        with_element = %{alias: alias, property: property, function: function, as: as}
        context = update_used_clauses_with_data(context, with_element)

        context =
          if(not is_nil(as)) do
            {_old_value, context} =
              Map.get_and_update(context, :variables, fn old_list ->
                {old_list, old_list ++ [as]}
              end)

            context
          else
            context
          end

        context = Map.put(context, :current_clause, :with)
        context

      _ ->
        context
    end
  end

  def with_function_and_property(context, _function, _alias, _property, _as) do
    context
  end

  @spec set(t(), atom(), accepted_value(), String.t()) :: t()
  def set(context, alias, value, operator \\ "=")

  def set(context, alias, value, operator) do
    set_property_on(context, alias, nil, value, operator, :none)
  end

  @spec set_property(t(), atom(), String.t(), accepted_value(), String.t()) :: t()
  def set_property(context, alias, property, value, operator \\ "=")

  def set_property(context, alias, property, value, operator) do
    set_property_on(context, alias, property, value, operator, :none)
  end

  @spec on_match_set(t(), atom(), accepted_value(), String.t()) :: t()
  def on_match_set(context, alias, value, operator \\ "=")

  def on_match_set(context, alias, value, operator) do
    set_property_on(context, alias, nil, value, operator, :match)
  end

  @spec on_match_set_property(t(), atom(), String.t(), accepted_value(), String.t()) :: t()
  def on_match_set_property(context, alias, property, value, operator \\ "=")

  def on_match_set_property(context, alias, property, value, operator) do
    set_property_on(context, alias, property, value, operator, :match)
  end

  @spec on_create_set(t(), atom(), accepted_value(), String.t()) :: t()
  def on_create_set(context, alias, value, operator \\ "=")

  def on_create_set(context, alias, value, operator) do
    set_property_on(context, alias, nil, value, operator, :create)
  end

  @spec on_create_set_property(t(), atom(), String.t(), accepted_value(), String.t()) :: t()
  def on_create_set_property(context, alias, property, value, operator \\ "=")

  def on_create_set_property(context, alias, property, value, operator) do
    set_property_on(context, alias, property, value, operator, :create)
  end

  @spec set_property_on(t(), atom(), String.t() | nil, accepted_value(), String.t(), :none | :match | :create) :: t()
  defp set_property_on(context, alias, property, value, operator, on)

  defp set_property_on(%{error: nil} = context, _alias, "", _value, _operator, _on) do
    Map.put(context, :error, "Provide property name. E.g. new() |> match() |> node(\"n\") |> with(\"toUpper\", \"n\", \"name\", \"Name\") |> return(\"Name\") |> ...")
  end

  defp set_property_on(%{error: nil} = context, alias, property, value, operator, on) do
    clause = case on do
      :none -> :set
      :match -> :on_match_set
      :create -> :on_create_set
    end
    current_clause = Map.get(context, :current_clause)
    context = if current_clause != clause do
        context = add_clause_if_not_present(context, clause)
        Map.put(context, :current_clause, clause)
    else
      context
    end
    context = if(operator == "=" or operator == "+=") do
      context
    else
      Map.put(context, :error, "Provided operator \"#{operator}\" is not supported. Only := (default) or :+= is supported. E.g. new() |> match() |> node(\"n\") |> node(\"n\") |> set_property(\"n\", \"age\", 100, :+=) |> ...")
    end
    context = check_if_provided_alias_present(context, alias)
    # check if value is an atom which indicates that it is an alias, so an entity has to be set to another entity. E.g. new |> match |> node(:n) |> node(:m) |> set(:n, :m) |> ...
    context = if(is_atom(value) and is_nil(property), do: check_if_provided_alias_present(context, value), else: context)
    context = check_if_match_ends_with_relationship(context)
    context =
      if(clause == :set) do
        context = check_if_match_clause_provided(context, clause)
        context
      else
        merge_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:merge)
        context =
          if(not merge_clause_present?) do
            Map.put(
              context,
              :error,
              "MERGE clause has to be provided first before using SET. E.g. new() |> merge() |> node(\"n\") |> node(\"m\") |> on_create_set(\"n\", \"m\") |> return(\"n\") |> ..."
            )
          else
            context
          end
        context
      end

    %{error: error} = context

    case error do
      nil ->
        set_element = %{alias: alias, property: property, value: value, operator: operator}
        context = update_used_clauses_with_data(context, set_element)
        context = Map.put(context, :current_clause, clause)
        context
      _ ->
        context
    end
  end

  defp set_property_on(context, _alias, _property, _value, _operator, _on) do
    context
  end

  @spec build_query(t()) :: {:ok, String.t()} | {:error, String.t()}
  def build_query(context) do
    QueryBuilder.build_query(context)
  end

  @spec add_clause_if_not_present(t(), atom()) :: t()
  defp add_clause_if_not_present(context, clause) do
    {_old_value, context} =
      Map.get_and_update(context, :used_clauses, fn old_list ->
        {old_list, old_list ++ [clause]}
      end)

    {_old_value, context} =
      Map.get_and_update(context, :used_clauses_with_data, fn old_list ->
        {old_list, old_list ++ [%{clause: clause, elements: []}]}
      end)

    context
  end

  @spec update_used_clauses_with_data(t(), map() | atom()) :: t()
  defp update_used_clauses_with_data(context, data) do
    # IO.puts("context")
    # IO.inspect(context)
    # IO.puts("data")
    # IO.inspect(data)
    used_clauses_with_data = Map.get(context, :used_clauses_with_data, [])

    {_old_value, updated_last_clause} =
      List.last(used_clauses_with_data, %{})
      |> Map.get_and_update(:elements, fn old_elements ->
        {old_elements, old_elements ++ [data]}
      end)

    updated_used_clauses_with_data =
      List.replace_at(used_clauses_with_data, -1, updated_last_clause)

    {_old_value, context} =
      Map.get_and_update(context, :used_clauses_with_data, fn old_map ->
        {old_map, updated_used_clauses_with_data}
      end)

    context
  end

  @spec check_if_provided_alias_present(t(), atom()) :: t()
  defp check_if_provided_alias_present(context, alias) do
    alias_present? =
      Map.get(context, :edges, %{}) |> Map.has_key?(alias) or
        Map.get(context, :nodes, %{}) |> Map.has_key?(alias)

    variable_present? = Map.get(context, :variables, []) |> Enum.member?(alias)
    if(not alias_present? and not variable_present?) do
      Map.put(
        context,
        :error,
        "Provided alias: \"#{alias}\" was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(\"n\") |> order_by_property(\"n\", \"age\") |> ..."
      )
    else
      context
    end
  end

  @spec check_if_match_ends_with_relationship(t()) :: t()
  defp check_if_match_ends_with_relationship(context) do
    if(is_struct(Map.get(context, :last_element), Edge)) do
      Map.put(
        context,
        :error,
        "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(\"n\") |> relationship_from_to(\"r\") |> node(\"m\") |> ..."
      )
    else
      context
    end
  end

  @spec check_if_match_clause_provided(t(), atom()) :: t()
  defp check_if_match_clause_provided(context, clause) do
    clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()
    match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:match)
    optional_match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:optional_match)
    context =
      if((not match_clause_present?) and (not optional_match_clause_present?)) do
        Map.put(
          context,
          :error,
          "MATCH or OPTIONAL MATCH clause has to be provided first before using #{clause_to_string}. E.g. new() |> match() |> node(\"n\") |> ..."
        )
      else
        context
      end
    context
  end

  def check_if_return_clause_already_provided(context, clause) do
    clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()
    return_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:return)
    return_distinct_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:return_distinct)
    context =
      if(return_clause_present? and return_distinct_clause_present?) do
        Map.put(context, :error, "#{clause_to_string} can't be provided after RETURN or/and RETURN DISTINCT clause. Istead have e.g. new() |> match |> node(:n) |> node(:m) |> return(:n) |> return(:m)")
      else
        context
      end
    context
  end
end
