defmodule RedisGraph.UtilTest do
  alias RedisGraph.Util
  use ExUnit.Case

  test "creates a random string of length n" do
    n = :rand.uniform(100)
    random_string = Util.random_string(n)
    assert String.length(random_string) == n

    possible_characters = to_string(Enum.to_list(?a..?z))

    random_string
    |> String.graphemes()
    |> Enum.each(fn char -> assert String.contains?(possible_characters, char) end)
  end

  test "surrounds a string with quotes" do
    test_string = "this is a string"
    quoted_string = Util.quote_string(test_string)
    assert quoted_string == "'" <> test_string <> "'"

    already_quoted = "'quoted string'"
    quoted_string = Util.quote_string(already_quoted)
    assert quoted_string == already_quoted

    non_string = 1
    quoted = Util.quote_string(non_string)
    assert quoted == non_string
  end
end
