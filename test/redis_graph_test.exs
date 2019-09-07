defmodule RedisGraphTest do
  use ExUnit.Case
  doctest RedisGraph

  test "greets the world" do
    assert RedisGraph.hello() == :world
  end
end
