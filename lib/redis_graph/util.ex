defmodule RedisGraph.Util do
  @moduledoc "Provide utility functions for RedisGraph modules."

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
  Surround a string with double quotes if not already.

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
end
