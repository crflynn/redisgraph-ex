defmodule RedisGraph.Util do
  def random_string(n \\ 10) do
    1..n
    |> Enum.reduce("", fn _, acc -> acc <> to_string(Enum.take_random(?a..?z, 1)) end)
  end

  def quote_string(v) when is_binary(v) do
    quote_if_not(v, 0) <> v <> quote_if_not(v, -1)
  end

  def quote_string(v) do
    v
  end

  defp quote_if_not(v, pos) do
    if String.at(v, pos) != "\"" do
      "\""
    else
      ""
    end
  end
end
