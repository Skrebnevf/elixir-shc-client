defmodule ChatClientTest do
  use ExUnit.Case
  doctest ChatClient

  test "greets the world" do
    assert ChatClient.hello() == :world
  end
end
