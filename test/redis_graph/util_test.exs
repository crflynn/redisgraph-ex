defmodule RedisGraph.UtilTest do
  alias RedisGraph.{Node, Relationship, Util}

  use ExUnit.Case

  setup_all do
    john = Node.new(%{labels: ["Person", "Student"], properties: %{name: "John Doe", age: 22}})

    japan =
      Node.new(%{labels: ["Place"], properties: %{name: "Japan", capital: "Tokyo", island: true}})

    relationship =
      Relationship.new(%{
        src_node: john,
        dest_node: japan,
        type: "TRAVELS_TO",
        properties: %{purpose: "pleasure", spent: 11.11}
      })

    %{john: john, japan: japan, relationship: relationship}
  end

  test "creates a random string of length n" do
    n = :rand.uniform(100)
    random_string = Util.random_string(n)
    assert String.length(random_string) == n

    possible_characters = to_string(Enum.to_list(?a..?z))

    random_string
    |> String.graphemes()
    |> Enum.each(fn char -> assert String.contains?(possible_characters, char) end)
  end

  test "gets the properties to a string",
       %{john: john, japan: japan, relationship: relationship} = _context do
    john_props = Util.properties_to_string(john.properties)
    japan_props = Util.properties_to_string(japan.properties)
    rel_props = Util.properties_to_string(relationship.properties)
    empty_props_from_map = Util.properties_to_string(%{})
    empty_props_from_list = Util.properties_to_string([])

    assert john_props == " {age: 22, name: 'John Doe'}"
    assert japan_props == " {capital: 'Tokyo', island: true, name: 'Japan'}"
    assert rel_props == " {purpose: 'pleasure', spent: 11.11}"
    assert empty_props_from_map == ""
    assert empty_props_from_list == ""
  end

  test "gets the node labels to a string", %{john: john, japan: japan} = _context do
    john_labels = Util.labels_to_string(john.labels)
    japan_labels = Util.labels_to_string(japan.labels)
    empty_labels_from_map = Util.labels_to_string(%{})
    empty_labels_from_list = Util.labels_to_string([])

    assert john_labels == ":Person:Student"
    assert japan_labels == ":Place"
    assert empty_labels_from_map == ""
    assert empty_labels_from_list == ""
  end

  test "gets the relationship type to a string", %{relationship: relationship} = _context do
    relationship_type = Util.type_to_string(relationship.type)
    empty_type_from_map = Util.type_to_string(%{})
    empty_type_from_list = Util.type_to_string([])

    assert relationship_type == ":TRAVELS_TO"
    assert empty_type_from_map == ""
    assert empty_type_from_list == ""
  end

  test "gets value to a string", _context do
    values_to_string =
      Util.value_to_string(["test", 11, 12.12, false, nil, ["hi", "bye"], %{me: "you"}])

    empty_value_to_string = ""

    assert values_to_string == "['test', 11, 12.12, false, null, ['hi', 'bye'], {me: 'you'}]"
    assert empty_value_to_string == ""
  end
end
