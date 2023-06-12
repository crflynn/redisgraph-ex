defmodule RedisGraph.Query do
  @moduledoc """
  Query module provides functions to build the cypther query for RedisGraph database.

  The module exposes functions that represent entities (Node/Relationship)
  and clauses (MATCH/WHERE/RETURN etc.) through which client can build
  the desired query and pass it to RedisGraph.query/3 to interact with the database.
  Internally Query structure holds the context, that contains data necessary when
  building the actual query. The context shouldn't be altered by the client directly,
  instead only public functions from this module should be, which would internally change it.

  The query supports the following clauses: `CREATE, MATCH, OPTIONAL MATCH,
  MERGE, DELETE, SET, ON MATCH SET, ON CREATE SET, WITH, WHERE, ORDER BY,
  LIMIT, SKIP, RETURN`.

  After building the query, you will end up with either `{:ok, query_message}`
  or `{:error, error_message}`.

  ## Examples
  ```
  # Creating a valid query
  {:ok, query} =
          Query.new()
          |> Query.match()
          |> Query.node(:n, ["Person"], %{age: 30, name: "John Doe", works: true})
          |> Query.relationship_from_to(:r, "TRAVELS_TO", %{purpose: "pleasure"})
          |> Query.node(:m, ["Place"], %{name: "Japan"})
          |> Query.return(:n)
          |> Query.return_property(:n, "age", :Age)
          |> Query.return(:m)
          |> Query.build_query()

  # query will hold
  # "MATCH "MATCH (n:Person {age: 30, name: 'John Doe', works: true})-[r:TRAVELS_TO {purpose: 'pleasure'}]->(m:Place {name: 'Japan'}) RETURN n, n.age AS Age, m"

  # Creating an invalid query
  {:error, error} =
          Query.new() |> Query.match() |> Query.node(:n, ["Person"], %{age: 30, name: "John Doe", works: true}) |> Query.relationship_from_to(:r, "TRAVELS_TO", %{purpose: "pleasure"}) |> Query.node(:m, ["Place"], %{name: "Japan"}) |> Query.build_query()

  # error will hold
  # "In case you provide MATCH, OPTIONAL MATCH - then RETURN, RETURN DISCTINCT or DELETE also has to be provided. E.g. new() |> match |> node(:n) |> return(:n)"
  ```

  You will specify the node through node() and relationship through either relationship_from_to() or relationship_to_from().
  ```
  {:ok, query} = Query.new()
                 |> Query.create()
                 |> Query.node(:n, ["Person"])
                 |> Query.relationship_from_to(:r, "TRAVELS_TO")
                 |> Query.node(:m, ["City"])
                 |> Query.relationship_from_to(:t, "IN")
                 |> Query.node(:b, ["Country"])
                 |> Query.relationship_to_from(:y, "HAS")
                 |> Query.node(:v, ["Emperor"])
                 |> Query.build_query()
  # query would hold
  # "CREATE (n:Person)-[r:TRAVELS_TO]->(m:City)-[t:IN]->(b:Country)<-[y:HAS]-(v:Emperor)"
  ```
  """

  alias RedisGraph.{Node, Relationship, Util}

  # MATCH, WHERE, ORDER BY, RETURN, RETURN DISTINCT, LIMIT, SKIP

  @type t() :: %__MODULE__{
          current_clause: clauses() | nil,
          last_element: RedisGraph.Node.t() | RedisGraph.Relationship.t() | nil,
          error: String.t() | nil,
          nodes: %{atom() => RedisGraph.Node.t()},
          relationships: %{atom() => RedisGraph.Relationship.t()},
          variables: [String.t()],
          used_clauses: [[atom()]] | [],
          used_clauses_with_data: [[map()]] | []
        }

  @typep clauses() ::
           :create
           | :match
           | :optional_match
           | :merge
           | :delete
           | :set
           | :on_match_set
           | :on_create_set
           | :with
           | :where
           | :order_by
           | :limit
           | :skip
           | :return

  @typep accepted_operator_in_where_clause() ::
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

  @typep accepted_value() :: String.t() | number() | boolean() | nil | list() | map()

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
    in: "IN",
    is: "IS",
    is_not: "IS NOT"
  }

  @accepted_operator_for_number_in_where_clause [
    :equals,
    :not_equal,
    :bigger,
    :bigger_or_equal,
    :smaller,
    :smaller_or_equal
  ]

  @accepted_operator_for_nil_in_where_clause [:is, :is_not]

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
    relationships: %{},
    variables: [],
    used_clauses: [],
    used_clauses_with_data: []
  ]

  def new() do
    struct(__MODULE__)
  end

  @doc """
  Add `MATCH` clause into the context and receive the updated context.
  After match/1 provide the entities which you want to match using
  node(), relationship_from_to, relationship_to_from() functions.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person {age: 30, name: 'John'}) RETURN n"
  ```
  """
  @spec match(t()) :: t()
  def match(%{error: nil} = context) do
    context = check_if_provided_context_has_correct_structure(context)
    context = add_clause_if_not_present(context, :match)
    context = check_if_return_clause_already_provided(context, :match)
    %{error: error} = context

    case error do
      nil -> Map.put(context, :current_clause, :match)
      _ -> context
    end
  end

  def match(context) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `OPTIONAL MATCH` clause into the context and receive the updated context.
  After optional_match/1 provide the entities which you want to match using
  node(), relationship_from_to, relationship_to_from() functions.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.optional_match() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "OPTIONAL MATCH (n:Person {age: 30, name: 'John'}) RETURN n"
  ```
  """
  @spec optional_match(t()) :: t()
  def optional_match(%{error: nil} = context) do
    context = check_if_provided_context_has_correct_structure(context)
    context = add_clause_if_not_present(context, :optional_match)
    context = check_if_return_clause_already_provided(context, :optional_match)
    %{error: error} = context

    case error do
      nil -> Map.put(context, :current_clause, :optional_match)
      _ -> context
    end
  end

  def optional_match(context) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `MERGE` clause into the context and receive the updated context.
  After merge/1 provide the entities which you want to match using
  node(), relationship_from_to, relationship_to_from() functions.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.merge() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MERGE (n:Person {age: 30, name: 'John'}) RETURN n"
  ```
  """
  @spec merge(t()) :: t()
  def merge(%{error: nil} = context) do
    context = check_if_provided_context_has_correct_structure(context)
    context = add_clause_if_not_present(context, :merge)
    context = check_if_return_clause_already_provided(context, :merge)
    %{error: error} = context

    case error do
      nil -> Map.put(context, :current_clause, :merge)
      _ -> context
    end
  end

  def merge(context) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `CREATE` clause into the context and receive the updated context.
  After create/1 provide the entities which you want to match using
  node(), relationship_from_to, relationship_to_from() functions.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.create() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "CREATE (n:Person {age: 30, name: 'John'}) RETURN n"
  ```
  """
  @spec create(t()) :: t()
  def create(%{error: nil} = context) do
    context = check_if_provided_context_has_correct_structure(context)
    context = add_clause_if_not_present(context, :create)
    context = check_if_return_clause_already_provided(context, :create)
    %{error: error} = context

    case error do
      nil -> Map.put(context, :current_clause, :create)
      _ -> context
    end
  end

  def create(context) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `DELETE` clause into the context and receive the updated context.
  Provide the `context` and `alias` (as atom) of the entity you want to delete.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.delete(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person {age: 30, name: 'John'}) DELETE n"
  ```
  If provided entity alias is was not mentioned before, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.create() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.delete(:m) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
  ```
  """
  @spec delete(t(), atom()) :: t()
  def delete(%{error: nil} = context, alias) do
    current_clause = Map.get(context, :current_clause)

    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != :delete do
        context = add_clause_if_not_present(context, :delete)
        Map.put(context, :current_clause, :delete)
      else
        context
      end

    context = check_if_provided_alias_present(context, alias)
    context = check_if_match_ends_with_relationship(context)
    context = check_if_alias_is_atom(context, alias)
    context = check_if_match_or_create_or_merge_clause_provided(context, :delete)

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
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add a Node to a clause and receive the updated context.
  Provide the `context`, `alias` (as atom) of the node you want to add and a list of `labels` (as Strings) or a map of `properties`.
  The function can be used along with `MATCH, OPTIONAL MATCH, CREATE, MERGE` clauses.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person) RETURN n"

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, %{age: 30, name: "John"}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n {age: 30, name: 'John'}) RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.node(:n, ["Person"]) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MATCH or OPTIONAL MATCH or CREATE or MERGE clause has to be provided first before using node(). E.g. new() |> match() |> node(:n) |> ..."
  ```
  """
  @spec node(t(), atom(), list(String.t())) :: t()
  def node(%{error: nil} = context, alias, labels) when is_list(labels) do
    node(context, alias, labels, %{})
  end

  @spec node(t(), atom(), map()) :: t()
  def node(%{error: nil} = context, alias, properties) when is_map(properties) do
    node(context, alias, [], properties)
  end

  @doc """
  Add a Node to a clause and receive the updated context.
  Provide the `context`, `alias` (as atom) of the node you want to add, a list of `labels` (as Strings) and a map of `properties`.
  The function can be used along with `MATCH, OPTIONAL MATCH, CREATE, MERGE` clauses.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person {age: 30, name: 'John'}) RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.node(:n, ["Person"], %{age: 30, name: "John"}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MATCH or OPTIONAL MATCH or CREATE or MERGE clause has to be provided first before using node(). E.g. new() |> match() |> node(:n) |> ..."
  ```
  """
  @spec node(t(), atom(), list(String.t()), map()) :: t()
  def node(context, alias, labels \\ [], properties \\ %{})

  def node(%{error: nil} = context, alias, labels, properties)
      when is_list(labels) and is_map(properties) do
    node = RedisGraph.Node.new(%{alias: alias, labels: labels, properties: properties})
    last_element = Map.get(context, :last_element)

    context = check_if_provided_context_has_correct_structure(context)
    context = check_if_alias_is_atom(context, alias)

    only_strings_in_labels_list? =
      Stream.map(labels, fn label -> is_binary(label) end) |> Enum.all?()

    context =
      if(only_strings_in_labels_list?) do
        context
      else
        Map.put(
          context,
          :error,
          "Provided labels must all be of string type."
        )
      end

    context = check_if_match_or_create_or_merge_clause_provided(context, "node()", false)

    # used_clauses_with_data = Map.get(context, :used_clauses_with_data, [])

    # alias_present? = List.last(used_clauses_with_data, %{})|> Map.get(:elements, []) |> Stream.map(fn element -> alias == element end) |> Enum.member?(true)
    # # alias_present? = Map.get(context, :relationships, %{}) |> Map.has_key?(alias) or Map.get(context, :nodes, %{}) |> Map.has_key?(alias)
    # context = if(alias_present?) do
    #   Map.put(
    #     context,
    #     :error,
    #     "Provided alias: :#{alias} was alreay mentioned before. Pass the another alias: e.g. new() |> match() |> node(:n) |> node(:m) |> order_by_property(:n, \"age\") |> ..."
    #   )
    # else
    #   context
    # end

    error = Map.get(context, :error)

    case error do
      nil ->
        context =
          if(is_struct(last_element, Relationship)) do
            alias = Map.get(last_element, :alias)
            dest_node = Map.get(last_element, :dest_node)

            new_relationship =
              if(is_nil(dest_node)) do
                Map.put(last_element, :dest_node, node)
              else
                Map.put(last_element, :src_node, node)
              end

            {_old_value, updated_context} =
              Map.get_and_update(context, :relationships, fn relationships ->
                {relationships, Map.put(relationships, alias, new_relationship)}
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

      _ ->
        context
    end
  end

  def node(%{error: nil} = context, alias, _labels, _properties) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Wrong parameters provided to node(:#{alias})"
        )

      _ ->
        context
    end
  end

  def node(context, _alias, _labels, _properties) do
    check_if_provided_context_has_correct_structure(context)
  end

  @spec relationship_from_to(t(), atom(), String.t()) :: t()
  def relationship_from_to(%{error: nil} = context, alias, type) when is_binary(type) do
    relationship_from_to(context, alias, type, %{})
  end

  @doc """
  Add a Relationship to a clause and receive the updated context.
  Provide the `context`, `alias` (as atom) of the relationship you want to add and a `type` (as Strings) or a map of `properties`.
  The function can be used along with `MATCH, OPTIONAL MATCH, CREATE, MERGE` clauses.

  relationship_from_to() will convert to `(:from_node)-[:rel]->(:to_node)`

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_from_to(:r, "KNOWS") |> Query.node(:m) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n)-[r:KNOWS]->(m) RETURN n"

  {:ok, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_from_to(:r, %{duration: 100}) |> Query.node(:m) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n)-[r {duration: 100}]->(m) RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_from_to(:r, %{duration: 100}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
  ```
  """
  @spec relationship_from_to(t(), atom(), map()) :: t()
  def relationship_from_to(%{error: nil} = context, alias, properties) when is_map(properties) do
    relationship_from_to(context, alias, "", properties)
  end

  @doc """
  Add a Relationship to a clause and receive the updated context.
  Provide the `context`, `alias` (as atom) of the relationship you want to add, a `type` (as Strings) or a map of `properties`.
  The function can be used along with `MATCH, OPTIONAL MATCH, CREATE, MERGE` clauses.

  relationship_from_to() will convert to `(:from_node)-[:rel]->(:to_node)`

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_from_to(:r, "TRAVELS", %{duration: 100}) |> Query.node(:m) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n)-[r:TRAVELS {duration: 100}]->(m) RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_from_to(:r, "TRAVELS", %{duration: 100}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
  ```
  """
  @spec relationship_from_to(t(), atom(), String.t(), map()) :: t()
  def relationship_from_to(context, alias, type \\ "", properties \\ %{})

  def relationship_from_to(%{error: nil} = context, alias, type, properties)
      when is_binary(type) and is_map(properties) do
    last_element = Map.get(context, :last_element)

    context = check_if_provided_context_has_correct_structure(context)

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
      if(is_struct(last_element, Relationship)) do
        context =
          Map.put(
            context,
            :error,
            "You cannot have multiple Relationships in a row. Add a Node between them with node() function"
          )

        context = Map.put(context, :last_element, nil)
        context
      else
        context
      end

    current_clause = Map.get(context, :current_clause)

    context =
      if(current_clause == :create and type == "") do
        Map.put(
          context,
          :error,
          "When you create a relationship, the type has to be provided. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r, \"WORKS\") |> ..."
        )
      else
        context
      end

    context = check_if_alias_is_atom(context, alias)

    context =
      check_if_match_or_create_or_merge_clause_provided(context, "relationship_from_to()", false)

    # alias_present? = Map.get(context, :relationships, %{}) |> Map.has_key?(alias) or Map.get(context, :nodes, %{}) |> Map.has_key?(alias)
    # context = if(alias_present?) do
    #   Map.put(
    #     context,
    #     :error,
    #     "Provided alias: :#{alias} was alreay mentioned before." <>
    #     " Pass the another alias: e.g. new() |> match() |> node(:n) |> relationship_from_to(:r, \"WORKS\")  |> relationship_from_to(:t, \"KNOWS\") |> order_by_property(:n, \"age\") |> ..."
    #   )
    # else
    #   context
    # end

    error = Map.get(context, :error)

    case error do
      nil ->
        relationship =
          RedisGraph.Relationship.new(%{
            alias: alias,
            type: type,
            properties: properties,
            src_node: last_element
          })

        {_old_value, context} =
          Map.get_and_update(context, :relationships, fn old_map ->
            {old_map, Map.put(old_map, alias, relationship)}
          end)

        context = update_used_clauses_with_data(context, alias)
        context = Map.put(context, :last_element, relationship)
        context

      _ ->
        context
    end
  end

  def relationship_from_to(%{error: nil} = context, alias, _type, _properties) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Wrong parameters provided to relationship_from_to(:#{alias})"
        )

      _ ->
        context
    end
  end

  def relationship_from_to(context, _alias, _type, _properties) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add a Relationship to a clause and receive the updated context.
  Provide the `context`, `alias` (as atom) of the relationship you want to add and a `type` (as Strings) or a map of `properties`.
  The function can be used along with `MATCH, OPTIONAL MATCH, CREATE, MERGE` clauses.

  relationship_to_from() will convert to `(:to_node)<-[:rel]-(:from_node)`

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_to_from(:r, "KNOWS") |> Query.node(:m) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n)<-[r:KNOWS]-(m) RETURN n"

  {:ok, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_to_from(:r, %{duration: 100}) |> Query.node(:m) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n)<-[r {duration: 100}]-(m) RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_to_from(:r, %{duration: 100}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
  ```
  """
  @spec relationship_to_from(t(), atom(), String.t()) :: t()
  def relationship_to_from(%{error: nil} = context, alias, type) when is_binary(type) do
    relationship_to_from(context, alias, type, %{})
  end

  @spec relationship_to_from(t(), atom(), map()) :: t()
  def relationship_to_from(%{error: nil} = context, alias, properties) when is_map(properties) do
    relationship_to_from(context, alias, "", properties)
  end

  @doc """
  Add a Relationship to a clause and receive the updated context.
  Provide the `context`, `alias` (as atom) of the relationship you want to add, a `type` (as Strings) or a map of `properties`.
  The function can be used along with `MATCH, OPTIONAL MATCH, CREATE, MERGE` clauses.

  relationship_to_from() will convert to `(:to_node)<-[:rel]-(:from_node)`

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_to_from(:r, "TRAVELS", %{duration: 100}) |> Query.node(:m) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n)<-[r:TRAVELS {duration: 100}]-(m) RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |>  Query.match |> Query.node(:n) |> Query.relationship_to_from(:r, "TRAVELS", %{duration: 100}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
  ```
  """
  @spec relationship_to_from(t(), atom(), String.t(), map()) :: t()
  def relationship_to_from(context, alias, type \\ "", properties \\ %{})

  def relationship_to_from(%{error: nil} = context, alias, type, properties)
      when is_binary(type) and is_map(properties) do
    last_element = Map.get(context, :last_element)

    context = check_if_provided_context_has_correct_structure(context)

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
      if(is_struct(last_element, Relationship)) do
        context =
          Map.put(
            context,
            :error,
            "You cannot have multiple Relationships in a row. Add a Node between them with node() function"
          )

        context = Map.put(context, :last_element, nil)
        context
      else
        context
      end

    current_clause = Map.get(context, :current_clause)

    context =
      if(current_clause == :create and type == "") do
        Map.put(
          context,
          :error,
          "When you create a relationship, the type has to be provided. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r, \"WORKS\") |> ..."
        )
      else
        context
      end

    context = check_if_alias_is_atom(context, alias)

    context =
      check_if_match_or_create_or_merge_clause_provided(context, "relationship_to_from()", false)

    # alias_present? = Map.get(context, :relationships, %{}) |> Map.has_key?(alias) or Map.get(context, :nodes, %{}) |> Map.has_key?(alias)
    # context = if(alias_present?) do
    #   Map.put(
    #     context,
    #     :error,
    #     "Provided alias: :#{alias} was alreay mentioned before." <>
    #     " Pass the another alias: e.g. new() |> match() |> node(:n) |> relationship_to_from(:r, \"WORKS\")  |> relationship_to_from(:t, \"KNOWS\") |> order_by_property(:n, \"age\") |> ..."
    #   )
    # else
    #   context
    # end

    error = Map.get(context, :error)

    case error do
      nil ->
        relationship =
          RedisGraph.Relationship.new(%{
            alias: alias,
            type: type,
            properties: properties,
            dest_node: last_element
          })

        {_old_value, context} =
          Map.get_and_update(context, :relationships, fn old_map ->
            {old_map, Map.put(old_map, alias, relationship)}
          end)

        context = update_used_clauses_with_data(context, alias)
        context = Map.put(context, :last_element, relationship)
        context

      _ ->
        context
    end
  end

  def relationship_to_from(%{error: nil} = context, alias, _type, _properties) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Wrong parameters provided to relationship_to_from(:#{alias})"
        )

      _ ->
        context
    end
  end

  def relationship_to_from(context, _alias, _type, _properties) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `WHERE` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Supported values(on the left) and operators (on the left):
  - type `String` -> provide `:equals, :not_equal, :bigger, :bigger_or_equal, :smaller, :smaller_or_equal, :starts_with, :ends_with, :contains`
  - type `number` -> `:equals, :not_equal, :bigger, :bigger_or_equal, :smaller, :smaller_or_equal`
  - type `boolean` -> `:equals`
  - type `nil` -> `:is, :is_not`
  - type `list` -> `:in`

  The operator will be converted to:
  - :equals -> "="
  - :not_equal -> "<>"
  - :bigger -> ">"
  - :bigger_or_equal -> ">="
  - :smaller -> "<"
  - :smaller_or_equal -> "<="
  - :starts_with -> "STARTS WITH"
  - :ends_with -> "ENDS WITH"
  - :contains -> "CONTAINS"
  - :in -> "IN"
  - :is -> "IS"
  - :is_not -> "IS NOT

  where() can be used just once. If you want to have several conditions in `WHERE` clause, use
  where() along with other functions, such as or_where()/or_not_where() etc.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE n.age > 5 RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :test, 5) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Provide property name. E.g. new() |> match() |> node(:n) |> where(:n, \"age\", :bigger, 20}) |> return(:n) |> ..."
        )

      _ ->
        context
    end
  end

  defp where(%{error: nil} = context, _alias, _property, _operator, "", _logical_operator) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Value can't be of empty string. E.g. new() |> match() |> node(:n) |> where({:n, \"age\", :contains, \"A\") |> return(:n) |> ..."
        )

      _ ->
        context
    end
  end

  defp where(%{error: nil} = context, alias, property, operator, value, logical_operator) do
    # check if where clause with :none or :not exists and in that case not give error
    # where or where_not put as first element and rest should be after it. where/where_not can be only once and after that only and/or func can be used
    current_clause = Map.get(context, :current_clause)

    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != :where do
        context = add_clause_if_not_present(context, :where)
        Map.put(context, :current_clause, :where)
      else
        context
      end

    where_clause_elements_size =
      Map.get(context, :used_clauses_with_data, [])
      |> List.last(%{})
      |> Map.get(:elements, [])
      |> length

    accepted_logical_operators =
      if(where_clause_elements_size == 0,
        do: [:none, :not],
        else: [:and, :or, :xor, :and_not, :or_not, :xor_not]
      )

    logical_operator_accepted? = Enum.member?(accepted_logical_operators, logical_operator)

    context =
      if(logical_operator_accepted?) do
        context
      else
        Map.put(
          context,
          :error,
          "Provided order of WHERE clauses is wrong. You first call either where() or where_not() and then any number of the following or_where()/and_where()/or_not_where() etc. " <>
            "E.g. new() |> match() |> node(:n) |> where(:n, \"age\", :bigger, 20) |> and_where(:n, \"name\", :contains, \"A\") |> return(:n) |> ..."
        )
      end

    context = check_if_provided_alias_present(context, alias)
    context = check_if_match_ends_with_relationship(context)
    context = check_if_alias_is_atom(context, alias)
    context = check_if_match_or_create_or_merge_clause_provided(context, :where)

    context =
      if(Map.has_key?(@accepted_operator_to_string_in_where_clause, operator)) do
        context
      else
        Map.put(
          context,
          :error,
          "Provided value: #{value} or/and operator: :#{operator} in the WHERE clause is not supported."
        )
      end

    value_accepted? =
      cond do
        is_number(value) && Enum.member?(@accepted_operator_for_number_in_where_clause, operator) ->
          true

        is_binary(value) && Enum.member?(@accepted_operator_for_binary_in_where_clause, operator) ->
          true

        is_nil(value) && Enum.member?(@accepted_operator_for_nil_in_where_clause, operator) ->
          true

        is_boolean(value) &&
            Enum.member?(@accepted_operator_for_boolean_in_where_clause, operator) ->
          true

        is_list(value) && Enum.member?(@accepted_operator_for_list_in_where_clause, operator) ->
          true

        true ->
          false
      end

    context =
      if(value_accepted?) do
        context
      else
        Map.put(
          context,
          :error,
          "Provided value: #{value} or/and operator: :#{operator} in the WHERE clause is not supported."
        )
      end

    %{error: error} = context

    case error do
      nil ->
        content = %{
          alias: alias,
          property: property,
          operator: Map.get(@accepted_operator_to_string_in_where_clause, operator),
          value: value
        }

        where_element = %{logical_operator: logical_operator, elements: [content]}
        context = update_used_clauses_with_data(context, where_element)
        context = Map.put(context, :current_clause, :where)
        context

      _ ->
        context
    end
  end

  defp where(context, _alias, _property, _operator, _value, _logical_operator) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `WHERE NOT` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Check where() to see the supported values and operators.

  where_not() can be used just once. If you want to have several conditions in `WHERE` clause, use
  where_not() along with other functions, such as or_where()/or_not_where() etc.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where_not(:n, "age", :bigger, 5) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE NOT n.age > 5 RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where_not(:n, "age", :test, 5) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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

  @doc """
  Add `WHERE ... OR ...` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Check where() to see the supported values and operators.

  or_where() is used when you want to have several logical conditions is `WHERE` clause,
  so where()/where_not() already needs to present as well.
  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.or_where(:n, "name", :contains, "A") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE n.age > 5 OR n.name CONTAINS 'A' RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.or_where(:n, "name", :test, "A") |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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

  @doc """
  Add `WHERE ... AND ...` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Check where() to see the supported values and operators.

  and_where() is used when you want to have several logical conditions is `WHERE` clause,
  so where()/where_not() already needs to present as well.
  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.and_where(:n, "name", :contains, "A") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE n.age > 5 AND n.name CONTAINS 'A' RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.and_where(:n, "name", :test, "A") |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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

  @doc """
  Add `WHERE ... XOR ...` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Check where() to see the supported values and operators.

  xor_where() is used when you want to have several logical conditions is `WHERE` clause,
  so where()/where_not() already needs to present as well.
  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.xor_where(:n, "name", :contains, "A") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE n.age > 5 XOR n.name CONTAINS 'A' RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.xor_where(:n, "name", :test, "A") |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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

  @doc """
  Add `WHERE ... OR NOT ...` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Check where() to see the supported values and operators.

  or_not_where() is used when you want to have several logical conditions is `WHERE` clause,
  so where()/where_not() already needs to present as well.
  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.or_not_where(:n, "name", :contains, "A") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE n.age > 5 OR NOT n.name CONTAINS 'A' RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.or_not_where(:n, "name", :test, "A") |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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

  @doc """
  Add `WHERE ... AND NOT ...` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Check where() to see the supported values and operators.

  and_not_where() is used when you want to have several logical conditions is `WHERE` clause,
  so where()/where_not() already needs to present as well.
  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.and_not_where(:n, "name", :contains, "A") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE n.age > 5 AND NOT n.name CONTAINS 'A' RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.and_not_where(:n, "name", :test, "A") |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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

  @doc """
  Add `WHERE ... XOR NOT ...` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to filter on,
  a `property` for the given entity, a single `operator` (as atom) and a `value`.

  Check where() to see the supported values and operators.

  xor_not_where() is used when you want to have several logical conditions is `WHERE` clause,
  so where()/where_not() already needs to present as well.
  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.xor_not_where(:n, "name", :contains, "A") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WHERE n.age > 5 XOR NOT n.name CONTAINS 'A' RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.where(:n, "age", :bigger, 5) |> Query.xor_not_where(:n, "name", :test, "A") |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
  ```
  """
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

  @doc """
  Add `ORDER BY` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, a `property`
  for the given entity on which you want to order and a `asc` boolean
  (if set to `true`, the order is ASC and if `false`, order is DESC).

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.order_by(:n, "age") |> Query.build_query()
  # query will hold
  # "MATCH (n) RETURN n ORDER BY n.age ASC"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.order_by(:n, "") |> Query.build_query()
  # error will hold
  # "Provide property name. E.g. new() |> match() |> node(:n) |> order_by(:n, \"age\") |> return(:n) |> ..."
  ```
  """
  @spec order_by(t(), atom(), String.t(), boolean()) :: t()
  def order_by(context, alias, property, asc \\ true)

  def order_by(%{error: nil} = context, _alias, "", _asc) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Provide property name. E.g. new() |> match() |> node(:n) |> order_by(:n, \"age\") |> return(:n) |> ..."
        )

      _ ->
        context
    end
  end

  def order_by(%{error: nil} = context, alias, property, asc) when is_binary(property) do
    current_clause = Map.get(context, :current_clause)

    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != :order_by do
        context = add_clause_if_not_present(context, :order_by)
        Map.put(context, :current_clause, :order_by)
      else
        context
      end

    context = check_if_provided_alias_present(context, alias)
    context = check_if_match_ends_with_relationship(context)
    context = check_if_alias_is_atom(context, alias)
    context = check_if_match_or_create_or_merge_clause_provided(context, :order_by)

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

  def order_by(%{error: nil} = context, _alias, _property, _asc) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Wrong parameters provided. E.g. new() |> match() |> node(:n) |> order_by(:n, \"age\") |> return(:n) |> ..."
        )

      _ ->
        context
    end
  end

  def order_by(context, _alias, _property, _asc) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `LIMIT` clause into the context and receive the updated context.
  Provide the `context` and `number` of rows you want to limit to.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.limit(10)|> Query.build_query()
  # query will hold
  # "MATCH (n) RETURN n LIMIT 10"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.limit("test")|> Query.build_query()
  # error will hold
  # "Wrong number parameter was probided, only non negatibe integers supported. E.g. new() |> match() |> node(:n) |> return(:n) |> limit(10)|> build_query()"
  ```
  """
  @spec limit(t(), non_neg_integer()) :: t()
  def limit(%{error: nil} = context, number) do
    current_clause = Map.get(context, :current_clause)

    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != :limit do
        context = add_clause_if_not_present(context, :limit)
        Map.put(context, :current_clause, :limit)
      else
        context
      end

    context =
      if(is_number(number) and number > 0) do
        context
      else
        Map.put(
          context,
          :error,
          "Wrong number parameter was probided, only non negatibe integers supported. E.g. new() |> match() |> node(:n) |> return(:n) |> limit(10)|> build_query()"
        )
      end

    context = check_if_match_or_create_or_merge_clause_provided(context, :limit)

    %{error: error} = context

    case error do
      nil ->
        context = update_used_clauses_with_data(context, number)
        context = Map.put(context, :current_clause, :limit)
        context

      _ ->
        context
    end
  end

  def limit(context, _number) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `SKIP` clause into the context and receive the updated context.
  Provide the `context` and `number` of rows you want to skip.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.skip(10)|> Query.build_query()
  # query will hold
  # "MATCH (n) RETURN n SKIP 10"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.skip("test")|> Query.build_query()
  # error will hold
  # "Wrong number parameter was probided, only non negatibe integers supported. E.g. new() |> match() |> node(:n) |> return(:n) |> skip(10)|> build_query()"
  ```
  """
  @spec skip(t(), non_neg_integer()) :: t()
  def skip(%{error: nil} = context, number) do
    current_clause = Map.get(context, :current_clause)

    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != :skip do
        context = add_clause_if_not_present(context, :skip)
        Map.put(context, :current_clause, :skip)
      else
        context
      end

    context =
      if(is_number(number) and number > 0) do
        context
      else
        Map.put(
          context,
          :error,
          "Wrong number parameter was probided, only non negatibe integers supported. E.g. new() |> match() |> node(:n) |> return(:n) |> skip(10)|> build_query()"
        )
      end

    context = check_if_match_ends_with_relationship(context)
    context = check_if_match_or_create_or_merge_clause_provided(context, :skip)

    %{error: error} = context

    case error do
      nil ->
        context = update_used_clauses_with_data(context, number)
        context = Map.put(context, :current_clause, :skip)
        context

      _ ->
        context
    end
  end

  def skip(context, _number) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `RETURN` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to return
  and an atom `as` that would hold the new name of the result.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.return(:n, :Person) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person) RETURN n AS Person"

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.node(:m, ["Dog"]) |> Query.return(:n) |> Query.return(:m) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person),(m:Dog) RETURN n, m"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.return(:m) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
  ```
  """
  @spec return(t(), atom(), atom() | nil) :: t()
  def return(context, alias, as \\ nil) do
    return_function_and_property(context, nil, alias, nil, as, false)
  end

  @doc """
  Add `RETURN` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, name of the `property`
  you want to return and an atom `as` that would hold the new name of the result.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.return_property(:n,"age", :Person) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person) RETURN n.age AS Person"

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.return(:n) |> Query.return_property(:n, "age") |> Query.build_query()
  # query will hold
  # "MATCH (n:Person) RETURN n, n.age"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.return_property(:m, "") |> Query.build_query()
  # error will hold
  # "Provide property name. E.g. new() |> match() |> node(:n) |> return_property(:n, \"age\") |> ..."
  ```
  """
  @spec return_property(t(), atom(), String.t(), atom() | nil) :: t()
  def return_property(context, alias, property, as \\ nil) do
    return_function_and_property(context, nil, alias, property, as, false)
  end

  @doc """
  Add `RETURN` clause into the context and receive the updated context.
  Provide the `context`, name of the `function` which should be called,
  `alias` (as atom) of the entity you want to return and and atom
  `as` that would hold the new name of the result.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"]) |> Query.return_property(:n,"age", :Person) |> Query.build_query()
  # query will hold
  # "MATCH (n) RETURN n, labels(n) AS Labels"

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.return_function("labels", :n, :Labels) |> Query.build_query()
  # query will hold
  # "MATCH (n) RETURN n, labels(n) AS Labels"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.return_function("", :n, :Labels) |> Query.build_query()
  # error will hold
  # "Provide function name. E.g. new() |> match() |> node(:n) |> return_function(\"toUpper\", :n) |> ..."
  ```
  """
  @spec return_function(t(), String.t(), atom(), atom() | nil) :: t()
  def return_function(context, function, alias, as \\ nil) do
    return_function_and_property(context, function, alias, nil, as, false)
  end

  @doc """
  Add `RETURN` clause into the context and receive the updated context.
  Provide the `context`, name of the `function` which should be called,
  `alias` (as atom) of the entity, name of the `property` you want to return
  and and atom `as` that would hold the new name of the result.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.return_function_and_property("toUpper", :n, "name", :Name) |> Query.build_query()
  # query will hold
  # "MATCH (n) RETURN n, toUpper(n.name) AS Name"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} =Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n) |> Query.return_function_and_property("toUpper", :n, "name", "Name") |> Query.build_query()
  # error will hold
  # ""Provided as attribute: Name needs to be an atom. E.g. Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n, :Node) |> Query.build_query()"
  ```
  """
  @spec return_function_and_property(t(), String.t(), atom(), String.t(), atom() | nil) :: t()
  def return_function_and_property(context, function, alias, property, as \\ nil) do
    return_function_and_property(context, function, alias, property, as, false)
  end

  @doc """
  Add `RETURN DISTINCT` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to return
  and an atom `as` that would hold the new name of the result.


  Look at return() for examples
  """
  @spec return_distinct(t(), atom(), atom() | nil) :: t()
  def return_distinct(context, alias, as \\ nil) do
    return_function_and_property(context, nil, alias, nil, as, true)
  end

  @doc """
  Add `RETURN DISTINCT` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, name of the `property`
  you want to return and an atom `as` that would hold the new name of the result.

  Look at return_property() for examples
  """
  @spec return_distinct_property(t(), atom(), String.t(), atom() | nil) :: t()
  def return_distinct_property(context, alias, property, as \\ nil) do
    return_function_and_property(context, nil, alias, property, as, true)
  end

  @doc """
  Add `RETURN DISTINCT` clause into the context and receive the updated context.
  Provide the `context`, name of the `function` which should be called,
  `alias` (as atom) of the entity you want to return and and atom
  `as` that would hold the new name of the result.

  Look at return_function() for examples
  """
  @spec return_distinct_function(t(), String.t(), atom(), atom() | nil) :: t()
  def return_distinct_function(context, function, alias, as \\ nil) do
    return_function_and_property(context, function, alias, nil, as, true)
  end

  @doc """
  Add `RETURN DISTINCT` clause into the context and receive the updated context.
  Provide the `context`, name of the `function` which should be called,
  `alias` (as atom) of the entity, name of the `property` you want to return
  and and atom `as` that would hold the new name of the result.

  Look at return_function_and_property() for examples
  """
  @spec return_distinct_function_and_property(t(), String.t(), atom(), String.t(), atom() | nil) ::
          t()
  def return_distinct_function_and_property(context, function, alias, property, as \\ nil) do
    return_function_and_property(context, function, alias, property, as, true)
  end

  @spec return_function_and_property(
          t(),
          String.t() | nil,
          atom(),
          String.t() | nil,
          atom() | nil,
          boolean()
        ) :: t()
  defp return_function_and_property(
         %{error: nil} = context,
         "",
         _alias,
         _property,
         _asc,
         _distinct
       ) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Provide function name. E.g. new() |> match() |> node(:n) |> return_function(\"toUpper\", :n) |> ..."
        )

      _ ->
        context
    end
  end

  defp return_function_and_property(
         %{error: nil} = context,
         _function,
         _alias,
         "",
         _asc,
         _distinct
       ) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Provide property name. E.g. new() |> match() |> node(:n) |> return_property(:n, \"age\") |> ..."
        )

      _ ->
        context
    end
  end

  defp return_function_and_property(
         %{error: nil} = context,
         function,
         alias,
         property,
         as,
         distinct
       ) do
    clause = if(distinct == false, do: :return, else: :return_distinct)
    current_clause = Map.get(context, :current_clause)
    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != clause do
        context = add_clause_if_not_present(context, clause)
        Map.put(context, :current_clause, clause)
      else
        context
      end

    context =
      if(is_nil(as) or is_atom(as)) do
        context
      else
        Map.put(
          context,
          :error,
          "Provided as attribute: #{as} needs to be an atom. E.g. Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n, :Node) |> Query.build_query()"
        )
      end

    context = check_if_provided_alias_present(context, alias)
    context = check_if_match_ends_with_relationship(context)
    context = check_if_alias_is_atom(context, alias)

    match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:match)

    optional_match_clause_present? =
      Map.get(context, :used_clauses, []) |> Enum.member?(:optional_match)

    create_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:create)
    merge_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:merge)

    context =
      if(
        not match_clause_present? and not create_clause_present? and not merge_clause_present? and
          not optional_match_clause_present?
      ) do
        Map.put(
          context,
          :error,
          "One of these clauses MATCH, CREATE, MERGE etc. has to be provided first before using RETURN. E.g. new() |> match() |> node(:n) |> return(:n)  |> ..."
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

  defp return_function_and_property(context, _function, _alias, _property, _as, _distinct) do
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Add `WITH` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity you want to chain
  and an atom `as` that would hold the new name of the result.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} =  Query.new() |> Query.match() |> Query.node(:n) |> Query.with(:n, :Node) |> Query.return(:Node) |> Query.build_query()
  # query will hold
  # "MATCH (n) WITH n AS Node RETURN Node"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.with(:m, :Node) |> Query.return(:Node) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
  ```
  """
  @spec with(t(), atom(), atom() | nil) :: t()
  def with(context, alias, as \\ nil) do
    with_function_and_property(context, nil, alias, nil, as)
  end

  @doc """
  Add `WITH` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, name of the `property`
  you want to return and an atom `as` that would hold the new name of the result.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} =  Query.new() |> Query.match() |> Query.node(:n) |> Query.with_property(:n,"age", :Age) |> Query.return(:Age) |> Query.build_query()
  # query will hold
  # "MATCH (n) WITH n.age AS Age RETURN Age"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.with_property(:m,"age", :Age) |> Query.return(:Node) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
  ```
  """
  @spec with_property(t(), atom(), String.t(), atom() | nil) :: t()
  def with_property(context, alias, property, as \\ nil) do
    with_function_and_property(context, nil, alias, property, as)
  end

  @doc """
  Add `WITH` clause into the context and receive the updated context.
  Provide the `context`, name of the `function` which should be called,
  `alias` (as atom) of the entity you want to return and and atom
  `as` that would hold the new name of the result.

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.with_function("labels", :n, :Labels) |> Query.return(:Labels) |> Query.build_query()
  # query will hold
  # "MATCH (n) WITH labels(n) AS Labels RETURN Labels"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.with_function("labels", :m, :Labels) |> Query.return(:Labels) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
  ```
  """
  @spec with_function(t(), String.t(), atom(), atom() | nil) :: t()
  def with_function(context, function, alias, as \\ nil) do
    with_function_and_property(context, function, alias, nil, as)
  end

  @doc """
  Add `WITH` clause into the context and receive the updated context.
  Provide the `context`, name of the `function` which should be called,
  `alias` (as atom) of the entity, name of the `property` you want to return
  and and atom `as` that would hold the new name of the result.

  Instead of entity alias, :* atom can be provided.
  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.with_function_and_property("toUpper", :n, "Name", :Name) |> Query.return(:Name) |> Query.build_query()
  # query will hold
  # "MATCH (n) WITH toUpper(n.Name) AS Name RETURN Name"

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.with(:*) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n) WITH * RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n) |> Query.with_function_and_property("toUpper", :m, "Name", :Name) |> Query.return(:Name) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
  ```
  """
  @spec with_function_and_property(
          t(),
          String.t() | nil,
          atom(),
          String.t() | nil,
          atom() | nil
        ) :: t()
  def with_function_and_property(context, function, alias, property, as \\ nil)

  def with_function_and_property(%{error: nil} = context, "", _alias, _property, _as) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Provide function name. E.g. new() |> match() |> node(:n) |> with_function_and_property(\"toUpper\", :n, \"name\", :Name) |> return(:Name) |>..."
        )

      _ ->
        context
    end
  end

  def with_function_and_property(%{error: nil} = context, _function, _alias, "", _as) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Provide property name. E.g. new() |> match() |> node(:n) |> with_function_and_property(\"toUpper\", :n, \"name\", :Name) |> return(:Name) |> ..."
        )

      _ ->
        context
    end
  end

  def with_function_and_property(%{error: nil} = context, function, alias, property, as) do
    current_clause = Map.get(context, :current_clause)

    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != :with do
        context = add_clause_if_not_present(context, :with)
        Map.put(context, :current_clause, :with)
      else
        context
      end

    # %{error: error} = context
    provided_wildcard? = alias == :*
    variable_present? = Map.get(context, :variables, []) |> Enum.member?(alias)

    alias_present? =
      Map.get(context, :relationships, %{}) |> Map.has_key?(alias) or
        Map.get(context, :nodes, %{}) |> Map.has_key?(alias)

    context =
      if(not provided_wildcard? and not alias_present? and not variable_present?) do
        Map.put(
          context,
          :error,
          "Provided alias: :#{alias} was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
        )
      else
        context
      end

    context =
      if(is_nil(as) or is_atom(as)) do
        context
      else
        Map.put(
          context,
          :error,
          "Provided as attribute: #{as} needs to be an atom. E.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
        )
      end

    context = check_if_match_ends_with_relationship(context)
    context = check_if_alias_is_atom(context, alias)
    context = check_if_match_or_create_or_merge_clause_provided(context, :with)

    %{error: error} = context

    case error do
      nil ->
        with_element = %{alias: alias, property: property, function: function, as: as}
        context = update_used_clauses_with_data(context, with_element)

        context =
          if is_nil(as) do
            context
          else
            {_old_value, context} =
              Map.get_and_update(context, :variables, fn old_list ->
                {old_list, old_list ++ [as]}
              end)

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

  @doc """
  Add `SET` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, new `value`
  you want to set and `operator`.

  `value` arbument can be of the following type:
  - String
  - number
  - boolean
  - nil
  - list
  - map

  `operator` can be:
  - "=" (default) -- for assignment
  - "+=" -- for update

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, %{age: 5, name: "John"}) |> Query.set(:n, %{}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n {age: 5, name: 'John'}) SET n = {} RETURN n"

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, %{age: 5, name: "John"}) |> Query.set(:n, %{works: false}, "+=") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n {age: 5, name: 'John'}) SET n += {works: false} RETURN n"
  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = uery.new() |> Query.match() |> Query.node(:n, %{age: 5, name: "John"}) |> Query.set(:m, %{}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
  ```
  """
  @spec set(t(), atom(), accepted_value(), String.t()) :: t()
  def set(context, alias, value, operator \\ "=")

  def set(context, alias, value, operator) do
    set_property_on(context, alias, nil, value, operator, :none)
  end

  @doc """
  Add `SET` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, name of the
  `property`, new `value` you want to set and `operator`.

  `value` arbument can be of the following type:
  - String
  - number
  - boolean
  - nil
  - list
  - map

  `operator` can be:
  - "=" (default) -- for assignment
  - "+=" -- for update

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, %{age: 5, name: "John"}) |> Query.set_property(:n, "age", 25) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n {age: 5, name: 'John'}) SET n.age = 25 RETURN n"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = uery.new() |> Query.match() |> Query.node(:n, %{age: 5, name: "John"}) |> Query.set_property(:m, "age", 25) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
  ```
  """
  @spec set_property(t(), atom(), String.t(), accepted_value(), String.t()) :: t()
  def set_property(context, alias, property, value, operator \\ "=")

  def set_property(context, alias, property, value, operator) do
    set_property_on(context, alias, property, value, operator, :none)
  end

  @doc """
  Add `ON MATCH SET` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, new `value`
  you want to set and `operator`.

  Should only be used when `MERGE` clause is provided first.

  `value` arbument can be of the following type:
  - String
  - number
  - boolean
  - nil
  - list
  - map

  `operator` can be:
  - "=" (default) -- for assignment
  - "+=" -- for update

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.merge() |> Query.node(:n, ["Person"], %{age: 5}) |> Query.on_match_set(:n, %{name: "Michael"}, "+=") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MERGE (n:Person {age: 5}) ON MATCH SET n += {name: 'Michael'} RETURN n"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = uery.new() |> Query.match() |> Query.node(:n, %{age: 5, name: "John"}) |> Query.on_match_set(:m, %{}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MERGE clause has to be provided first before using ON MATCH SET. E.g. new() |> merge() |> node(:n) |> node(:m) |> on_create_set(:n, \"m\") |> return(:n) |> ..."
  ```
  """
  @spec on_match_set(t(), atom(), accepted_value(), String.t()) :: t()
  def on_match_set(context, alias, value, operator \\ "=")

  def on_match_set(context, alias, value, operator) do
    set_property_on(context, alias, nil, value, operator, :match)
  end

  @doc """
  Add `ON MATCH SET` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, name of the
  `property`, new `value` you want to set and `operator`.

  Should only be used when `MERGE` clause is provided first.

  `value` arbument can be of the following type:
  - String
  - number
  - boolean
  - nil
  - list
  - map

  `operator` can be:
  - "=" (default) -- for assignment
  - "+=" -- for update

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.merge() |> Query.node(:n, ["Person"], %{age: 5}) |> Query.on_match_set_property(:n, "age", 50) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MERGE (n:Person {age: 5}) ON MATCH SET n.age = 50 RETURN n"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"], %{age: 5}) |> Query.on_match_set_property(:n, "age", 50) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MERGE clause has to be provided first before using ON MATCH SET. E.g. new() |> merge() |> node(:n) |> node(:m) |> on_create_set(:n, \"m\") |> return(:n) |> ..."
  ```
  """
  @spec on_match_set_property(t(), atom(), String.t(), accepted_value(), String.t()) :: t()
  def on_match_set_property(context, alias, property, value, operator \\ "=")

  def on_match_set_property(context, alias, property, value, operator) do
    set_property_on(context, alias, property, value, operator, :match)
  end

  @doc """
  Add `ON CREATE SET` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, new `value`
  you want to set and `operator`.

  Should only be used when `MERGE` clause is provided first.

  `value` arbument can be of the following type:
  - String
  - number
  - boolean
  - nil
  - list
  - map

  `operator` can be:
  - "=" (default) -- for assignment
  - "+=" -- for update

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.merge() |> Query.node(:n, ["Person"], %{age: 5}) |> Query.on_create_set(:n, %{name: "Michael"}, "+=") |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MERGE (n:Person {age: 5}) ON CREATE SET n += {name: 'Michael'} RETURN n"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = uery.new() |> Query.match() |> Query.node(:n, %{age: 5, name: "John"}) |> Query.on_create_set(:m, %{}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MERGE clause has to be provided first before using ON CREATE SET. E.g. new() |> merge() |> node(:n) |> node(:m) |> on_create_set(:n, \"m\") |> return(:n) |> ..."
  ```
  """
  @spec on_create_set(t(), atom(), accepted_value(), String.t()) :: t()
  def on_create_set(context, alias, value, operator \\ "=")

  def on_create_set(context, alias, value, operator) do
    set_property_on(context, alias, nil, value, operator, :create)
  end

  @doc """
  Add `ON CREATE SET` clause into the context and receive the updated context.
  Provide the `context`, `alias` (as atom) of the entity, name of the
  `property`, new `value` you want to set and `operator`.

  Should only be used when `MERGE` clause is provided first.

  `value` arbument can be of the following type:
  - String
  - number
  - boolean
  - nil
  - list
  - map

  `operator` can be:
  - "=" (default) -- for assignment
  - "+=" -- for update

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.merge() |> Query.node(:n, ["Person"], %{age: 5}) |> Query.on_create_set_property(:n, "age", 50) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MERGE (n:Person {age: 5}) ON CREATE SET n.age = 50 RETURN n"

  ```
  If the client uses the function incorrectly, the error will be persisted and
  returned when the client will try to build the query.

  ## Example
  ```
  {:error, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"], %{age: 5}) |> Query.on_create_set_property(:n, "age", 50) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "MERGE clause has to be provided first before using ON CREATE SET. E.g. new() |> merge() |> node(:n) |> node(:m) |> on_create_set(:n, \"m\") |> return(:n) |> ..."
  ```
  """
  @spec on_create_set_property(t(), atom(), String.t(), accepted_value(), String.t()) :: t()
  def on_create_set_property(context, alias, property, value, operator \\ "=")

  def on_create_set_property(context, alias, property, value, operator) do
    set_property_on(context, alias, property, value, operator, :create)
  end

  @spec set_property_on(
          t(),
          atom(),
          String.t() | nil,
          accepted_value(),
          String.t(),
          :none | :match | :create
        ) :: t()
  defp set_property_on(context, alias, property, value, operator, on)

  defp set_property_on(%{error: nil} = context, _alias, "", _value, _operator, _on) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        Map.put(
          context,
          :error,
          "Provide property name. E.g. new() |> match() |> node(:n) |> set_property(:n, \"name\", :Name) |> return(:n) |> ..."
        )

      _ ->
        context
    end
  end

  defp set_property_on(%{error: nil} = context, alias, property, value, operator, on) do
    clause =
      case on do
        :none -> :set
        :match -> :on_match_set
        :create -> :on_create_set
      end

    current_clause = Map.get(context, :current_clause)

    context = check_if_provided_context_has_correct_structure(context)

    context =
      if current_clause != clause do
        context = add_clause_if_not_present(context, clause)
        Map.put(context, :current_clause, clause)
      else
        context
      end

    context =
      if(operator == "=" or operator == "+=") do
        context
      else
        Map.put(
          context,
          :error,
          "Provided operator \"#{operator}\" is not supported. Only := (default) or :+= is supported. E.g. new() |> match() |> node(:n) |> node(:n) |> set_property(:n, \"age\", 100, :+=) |> ..."
        )
      end

    context = check_if_provided_alias_present(context, alias)

    # check if value is an atom which indicates that it is an alias, so an entity has to be set to another entity. E.g. new |> match |> node(:n) |> node(:m) |> set(:n, :m) |> ...
    context =
      if(is_atom(value) and is_nil(property),
        do: check_if_provided_alias_present(context, value),
        else: context
      )

    context = check_if_match_ends_with_relationship(context)
    context = check_if_alias_is_atom(context, alias)

    context =
      if(clause == :set) do
        clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()
        match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:match)

        optional_match_clause_present? =
          Map.get(context, :used_clauses, []) |> Enum.member?(:optional_match)

        create_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:create)

        context =
          if(
            not match_clause_present? and not optional_match_clause_present? and
              not create_clause_present?
          ) do
            Map.put(
              context,
              :error,
              "MATCH or OPTIONAL MATCH or CREATE clause has to be provided first before using #{clause_to_string}. E.g. new() |> match() |> node(:n) |> ..."
            )
          else
            context
          end

        context
      else
        merge_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:merge)
        clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()

        context =
          if merge_clause_present? do
            context
          else
            Map.put(
              context,
              :error,
              "MERGE clause has to be provided first before using #{clause_to_string}. E.g. new() |> merge() |> node(:n) |> node(:m) |> on_create_set(:n, \"m\") |> return(:n) |> ..."
            )
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
    check_if_provided_context_has_correct_structure(context)
  end

  @doc """
  Function used to build the query string from the Redisgraph.Query context.
  Function receives the `context` as argument and returns either `{:ok, query_string}`
  or `{:error, error_message}`

  ## Example
  ```
  alias RedisGraph.{Query}

  {:ok, query} = Query.new() |> Query.match() |> Query.node(:n, ["Person"], %{age: 5}) |> Query.return(:n) |> Query.build_query()
  # query will hold
  # "MATCH (n:Person {age: 5}) RETURN n"
  ```
  If the client uses the function incorrectly, the error will be returned.

  ## Example
  ```
  {:error, query} = Query.match(%{}) |> Query.node(:n, ["Person"], %{age: 5}) |> Query.return(:n) |> Query.build_query()
  # error will hold
  # "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
  ```
  """

  # @spec build_query(t()) :: {:ok, String.t()} | {:error, String.t()}
  # def build_query(context) do
  #   context = check_if_match_ends_with_relationship(context)
  #   context = check_if_return_clause_is_provided_in_case_match_clause_is_present(context)
  #   context = check_if_provided_context_has_correct_structure(context)
  #   QueryBuilder.build_query(context)
  # end

  @spec build_query(t()) :: {:ok, String.t()} | {:error, String.t()}
  def build_query(%{error: nil} = context) do
    context = check_if_provided_context_has_correct_structure(context)
    context = check_if_match_ends_with_relationship(context)
    context = check_if_return_clause_is_provided_in_case_match_clause_is_present(context)
    %{error: error} = context

    case error do
      nil ->
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
              :where -> build_query_for_where_clause(context, elements)
              :order_by -> build_query_for_order_by_clause(context, elements)
              :limit -> build_query_for_limit_or_skip_clause(context, clause, elements)
              :skip -> build_query_for_limit_or_skip_clause(context, clause, elements)
              :with -> build_query_for_return_or_with_clause(context, clause, elements)
              :return -> build_query_for_return_or_with_clause(context, clause, elements)
              :return_distinct -> build_query_for_return_or_with_clause(context, clause, elements)
              _ -> "!!!Provided clause -- #{clause} is not yet supported!!!"
            end
          end)

        final_query = Enum.join(query_list, " ")
        {:ok, final_query}

      _ ->
        {:error, error}
    end
  end

  def build_query(context) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context
    {:error, error}
  end

  @spec build_query_for_general_clause(t(), atom(), list(map())) :: String.t()
  defp build_query_for_general_clause(context, clause, elements) do
    {_last_element, query} =
      Enum.reduce(elements, {nil, ""}, fn element_alias, acc ->
        {last_element, query} = acc
        node = Map.get(context, :nodes, %{}) |> Map.get(element_alias, nil)
        relationship = Map.get(context, :relationships, %{}) |> Map.get(element_alias, nil)

        cond do
          is_struct(node, Node) and is_struct(last_element, Node) ->
            last_element = node

            query =
              query <>
                ",(#{Util.value_to_string(node.alias)}#{Util.labels_to_string(node.labels)}#{Util.properties_to_string(node.properties)})"

            {last_element, query}

          is_struct(node, Node) ->
            last_element = node

            query =
              query <>
                "(#{Util.value_to_string(node.alias)}#{Util.labels_to_string(node.labels)}#{Util.properties_to_string(node.properties)})"

            {last_element, query}

          is_struct(relationship, Relationship) and is_struct(last_element, Node) and
              relationship.src_node.alias == last_element.alias ->
            last_element = relationship

            query =
              query <>
                "-[#{Util.value_to_string(relationship.alias)}#{Util.type_to_string(relationship.type)}#{Util.properties_to_string(relationship.properties)}]->"

            {last_element, query}

          is_struct(relationship, Relationship) and is_struct(last_element, Node) and
              relationship.dest_node.alias == last_element.alias ->
            last_element = relationship

            query =
              query <>
                "<-[#{Util.value_to_string(relationship.alias)}#{Util.type_to_string(relationship.type)}#{Util.properties_to_string(relationship.properties)}]-"

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

  @spec build_query_for_where_clause(t(), list(map())) :: String.t()
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

            "#{logical_operator_to_string}#{Util.value_to_string(alias)}.#{property} #{operator} #{Util.value_to_string(value)}"
          end)

        Enum.join(inner_query_list, " ")
      end)

    query_list_joined = Enum.join(query_list, " ")
    "WHERE #{query_list_joined}"
  end

  @spec build_query_for_return_or_with_clause(t(), atom(), list(map())) :: String.t()
  defp build_query_for_return_or_with_clause(_context, clause, elements) do
    clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()

    query_list =
      Stream.map(elements, fn element ->
        %{alias: alias, property: property, function: function, as: as} = element

        cond do
          not is_nil(alias) and not is_nil(property) and not is_nil(function) and not is_nil(as) ->
            "#{function}(#{Util.value_to_string(alias)}.#{property}) AS #{as}"

          not is_nil(alias) and not is_nil(property) and not is_nil(function) ->
            "#{function}(#{Util.value_to_string(alias)}.#{property})"

          not is_nil(alias) and not is_nil(function) and not is_nil(as) ->
            "#{function}(#{Util.value_to_string(alias)}) AS #{as}"

          not is_nil(alias) and not is_nil(function) ->
            "#{function}(#{Util.value_to_string(alias)})"

          not is_nil(alias) and not is_nil(property) and not is_nil(as) ->
            "#{Util.value_to_string(alias)}.#{property} AS #{as}"

          not is_nil(alias) and not is_nil(property) ->
            "#{Util.value_to_string(alias)}.#{property}"

          not is_nil(alias) and not is_nil(as) ->
            "#{Util.value_to_string(alias)} AS #{as}"

          not is_nil(alias) ->
            "#{Util.value_to_string(alias)}"

          true ->
            "Wrong parameters provided to #{clause} function"
        end
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "#{clause_to_string} #{query_list_joined}"
  end

  @spec build_query_for_order_by_clause(t(), list(map())) :: String.t()
  defp build_query_for_order_by_clause(_context, elements) do
    query_list =
      Stream.map(elements, fn element ->
        %{property: property, alias: alias, order: order} = element
        "#{Util.value_to_string(alias)}.#{property} #{order}"
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "ORDER BY #{query_list_joined}"
  end

  @spec build_query_for_set_clause(t(), atom(), list(map())) :: String.t()
  defp build_query_for_set_clause(_context, clause, elements) do
    clause_to_string =
      if(clause == :set,
        do: "SET",
        else: Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()
      )

    query_list =
      Stream.map(elements, fn element ->
        %{alias: alias, property: property, operator: operator, value: value} = element
        "#{Util.value_to_string(alias)} #{operator} #{Util.value_to_string(value)}"

        cond do
          not is_nil(alias) and not is_nil(property) ->
            "#{Util.value_to_string(alias)}.#{property} #{operator} #{Util.value_to_string(value)}"

          not is_nil(alias) ->
            "#{Util.value_to_string(alias)} #{operator} #{Util.value_to_string(value)}"

          true ->
            "Wrong parameters provided to #{clause} function"
        end
      end)

    query_list_joined = Enum.join(query_list, ", ")
    "#{clause_to_string} #{query_list_joined}"
  end

  @spec build_query_for_delete_clause(t(), list(map())) :: String.t()
  defp build_query_for_delete_clause(_context, elements) do
    query_list = Enum.join(elements, ", ")
    "DELETE #{query_list}"
  end

  @spec build_query_for_limit_or_skip_clause(t(), atom(), list(map())) :: String.t()
  defp build_query_for_limit_or_skip_clause(_context, clause, elements) do
    clause_to_string = Atom.to_string(clause) |> String.upcase()
    query_list = Enum.map(elements, fn element -> "#{clause_to_string} #{element}" end)
    Enum.join(query_list, " ")
  end

  @spec add_clause_if_not_present(t(), atom()) :: t()
  defp add_clause_if_not_present(%{error: nil} = context, clause) do
    context = check_if_provided_context_has_correct_structure(context)
    %{error: error} = context

    case error do
      nil ->
        {_old_value, context} =
          Map.get_and_update(context, :used_clauses, fn old_list ->
            {old_list, old_list ++ [clause]}
          end)

        {_old_value, context} =
          Map.get_and_update(context, :used_clauses_with_data, fn old_list ->
            {old_list, old_list ++ [%{clause: clause, elements: []}]}
          end)

        context

      _ ->
        context
    end
  end

  defp add_clause_if_not_present(context, _clause) do
    context
  end

  @spec update_used_clauses_with_data(t(), map() | atom()) :: t()
  defp update_used_clauses_with_data(%{error: nil} = context, data) do
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

  defp update_used_clauses_with_data(context, _data) do
    context
  end

  @spec check_if_provided_alias_present(t(), atom()) :: t()
  defp check_if_provided_alias_present(%{error: nil} = context, alias) do
    alias_present? =
      Map.get(context, :relationships, %{}) |> Map.has_key?(alias) or
        Map.get(context, :nodes, %{}) |> Map.has_key?(alias)

    variable_present? = Map.get(context, :variables, []) |> Enum.member?(alias)

    if(not alias_present? and not variable_present?) do
      Map.put(
        context,
        :error,
        "Provided alias: :#{alias} was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
      )
    else
      context
    end
  end

  defp check_if_provided_alias_present(context, _alias) do
    context
  end

  @spec check_if_alias_is_atom(t(), any()) :: t()
  defp check_if_alias_is_atom(%{error: nil} = context, alias) do
    if(is_atom(alias)) do
      context
    else
      Map.put(
        context,
        :error,
        "Provided alias is not an atom, only atoms are accepted. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
      )
    end
  end

  defp check_if_alias_is_atom(context, _alias) do
    context
  end

  @spec check_if_match_ends_with_relationship(t()) :: t()
  defp check_if_match_ends_with_relationship(%{error: nil} = context) do
    if(is_struct(Map.get(context, :last_element), Relationship)) do
      Map.put(
        context,
        :error,
        "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
      )
    else
      context
    end
  end

  defp check_if_match_ends_with_relationship(context) do
    context
  end

  @spec check_if_match_or_create_or_merge_clause_provided(t(), atom()) :: t()
  defp check_if_match_or_create_or_merge_clause_provided(context, clause, alter \\ true)

  defp check_if_match_or_create_or_merge_clause_provided(%{error: nil} = context, clause, alter) do
    clause_to_string =
      if(alter,
        do: Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase(),
        else: clause
      )

    match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:match)

    optional_match_clause_present? =
      Map.get(context, :used_clauses, []) |> Enum.member?(:optional_match)

    merge_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:merge)
    create_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:create)

    context =
      if not match_clause_present? and not optional_match_clause_present? and
           not create_clause_present? and not merge_clause_present? do
        Map.put(
          context,
          :error,
          "MATCH or OPTIONAL MATCH or CREATE or MERGE clause has to be provided first before using #{clause_to_string}. E.g. new() |> match() |> node(:n) |> ..."
        )
      else
        context
      end

    context
  end

  defp check_if_match_or_create_or_merge_clause_provided(context, _clause, _alter) do
    context
  end

  defp check_if_return_clause_already_provided(%{error: nil} = context, clause) do
    clause_to_string = Atom.to_string(clause) |> String.replace("_", " ") |> String.upcase()
    return_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:return)

    return_distinct_clause_present? =
      Map.get(context, :used_clauses, []) |> Enum.member?(:return_distinct)

    context =
      if return_clause_present? and return_distinct_clause_present? do
        Map.put(
          context,
          :error,
          "#{clause_to_string} can't be provided after RETURN or/and RETURN DISTINCT clause. Istead have e.g. new() |> match |> node(:n) |> node(:m) |> return(:n) |> return(:m)"
        )
      else
        context
      end

    context
  end

  defp check_if_return_clause_already_provided(context, _clause) do
    context
  end

  defp check_if_return_clause_is_provided_in_case_match_clause_is_present(%{error: nil} = context) do
    match_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:match)

    optional_match_clause_present? =
      Map.get(context, :used_clauses, []) |> Enum.member?(:optional_match)

    context =
      if match_clause_present? or optional_match_clause_present? do
        filtered_size =
          Map.get(context, :used_clauses_with_data, [])
          |> Enum.filter(fn %{clause: clause, elements: elements} ->
            (clause == :match or clause == :optional_match) and length(elements) > 0
          end)
          |> length()

        filtered_size_enough? = filtered_size > 0
        return_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:return)

        return_distinct_clause_present? =
          Map.get(context, :used_clauses, []) |> Enum.member?(:return_distinct)

        delete_clause_present? = Map.get(context, :used_clauses, []) |> Enum.member?(:delete)

        inner_context =
          if (return_clause_present? or return_distinct_clause_present? or delete_clause_present?) and
               filtered_size_enough? do
            context
          else
            Map.put(
              context,
              :error,
              "In case you provide MATCH, OPTIONAL MATCH - then RETURN, RETURN DISCTINCT or DELETE also has to be provided. E.g. new() |> match |> node(:n) |> return(:n)"
            )
          end

        inner_context
      else
        context
      end

    context
  end

  defp check_if_return_clause_is_provided_in_case_match_clause_is_present(context) do
    context
  end

  defp check_if_provided_context_has_correct_structure(context) do
    if is_struct(context, __MODULE__) do
      context
    else
      new()
      |> Map.put(
        :error,
        "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
      )
    end
  end
end
