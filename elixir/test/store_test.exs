defmodule ChorusDraft.StoreTest do
  use ExUnit.Case
  import Bitwise
  alias ChorusDraft.{Error, Platform, Store}

  setup do
    dir = Path.join(System.tmp_dir!(), "chorus-draft-store-#{System.unique_integer([:positive])}")
    Store.new(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "state persists atomically with private permissions", %{dir: dir} do
    assert item = Store.stage(dir, %{"text" => "hello"})
    assert [saved] = Store.drafts(dir)
    assert saved["id"] == item["id"]

    if Platform.os() != "windows",
      do: assert((File.stat!(Path.join(dir, "state.json")).mode &&& 0o777) == 0o600)
  end

  test "corrupt state fails closed and remains untouched", %{dir: dir} do
    path = Path.join(dir, "state.json")
    File.write!(path, "{broken")
    assert_raise Error, fn -> Store.drafts(dir) end
    assert File.read!(path) == "{broken"
  end

  test "opt-outs are retained without an eviction cap", %{dir: dir} do
    Store.transaction(dir, fn state ->
      blocked = for n <- 1..10_000, do: "blocked#{n}.example"
      {nil, Map.put(state, "blocked", blocked)}
    end)

    Store.block(dir, "blocked10010.example")
    assert Store.blocked?(dir, "blocked1.example")
    assert Store.blocked?(dir, "blocked10010.example")
  end

  test "duplicates, daily limit, and author cooldown are atomic", %{dir: dir} do
    assert Store.stage(dir, %{"author" => "alice"}, source: "1", unsolicited: true)
    refute Store.stage(dir, %{"author" => "alice"}, source: "2", unsolicited: true)
    refute Store.stage(dir, %{"author" => "bob"}, source: "1", unsolicited: true)

    for n <- 1..4 do
      assert Store.stage(dir, %{"author" => "author#{n}"},
               source: "source#{n}",
               unsolicited: true
             )
    end

    refute Store.available?(dir, author: "new", unsolicited: true)
  end

  test "a changed or already claimed draft cannot publish", %{dir: dir} do
    item = Store.stage(dir, %{"text" => "reviewed"})

    Store.transaction(dir, fn state ->
      {nil, put_in(state, ["drafts", Access.at(0), "text"], "changed")}
    end)

    assert_raise Error, fn ->
      Store.transition(dir, item["id"], "pending", "publishing", expected: item)
    end

    Store.transition(dir, item["id"], "pending", "publishing")
    assert_raise Error, fn -> Store.transition(dir, item["id"], "pending", "publishing") end
  end
end
