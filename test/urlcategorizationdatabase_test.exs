defmodule URLCategorizationDatabaseTest do
  use ExUnit.Case

  test "constructs a client" do
    client = URLCategorizationDatabase.Client.new("test")
    assert client.api_key == "test"
  end
end
