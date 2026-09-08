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

  test "automatic claims enforce one in flight, blocked actors, and a persistent daily budget", %{
    dir: dir
  } do
    blocked = Store.stage(dir, %{"text" => "blocked"})
    Store.block(dir, "alice")
    assert Store.claim_automatic(dir, blocked, actors: ["Alice"]) == {:error, :blocked}

    first = Store.stage(dir, %{"text" => "first"})
    assert {:ok, claimed} = Store.claim_automatic(dir, first)
    assert claimed["status"] == "publishing"
    assert claimed["publication_mode"] == "automatic"

    second = Store.stage(dir, %{"text" => "second"})
    assert Store.claim_automatic(dir, second) == {:error, :unresolved}
    Store.transition(dir, first["id"], "publishing", "published")

    for n <- 2..5 do
      item = Store.stage(dir, %{"text" => "attempt #{n}"})
      assert {:ok, _claimed} = Store.claim_automatic(dir, item)
      Store.transition(dir, item["id"], "publishing", "published")
    end

    limited = Store.stage(dir, %{"text" => "held"})
    assert Store.claim_automatic(dir, limited) == {:error, :limit}

    assert Jason.decode!(File.read!(Path.join(dir, "state.json")))["automatic"]
           |> length() == 5
  end

  test "ambiguous and crash-stranded publications block automatic claims", %{dir: dir} do
    uncertain = Store.stage(dir, %{"text" => "uncertain"})
    Store.transition(dir, uncertain["id"], "pending", "publishing")
    Store.transition(dir, uncertain["id"], "publishing", "uncertain")

    held = Store.stage(dir, %{"text" => "held"})
    assert Store.claim_automatic(dir, held) == {:error, :unresolved}

    Store.transaction(dir, fn state ->
      drafts =
        Enum.map(state["drafts"], fn draft ->
          cond do
            draft["id"] == uncertain["id"] ->
              Map.put(draft, "status", "published")

            draft["id"] == held["id"] ->
              draft
              |> Map.put("status", "publishing")
              |> Map.put("claimed_at", System.system_time(:second) - 301)
          end
        end)

      {nil, Map.put(state, "drafts", drafts)}
    end)

    assert Enum.find(Store.drafts(dir), &(&1["id"] == held["id"]))["status"] == "uncertain"

    next = Store.stage(dir, %{"text" => "next"})
    assert Store.claim_automatic(dir, next) == {:error, :unresolved}
  end

  test "operators can reject uncertain drafts so automatic mode can resume", %{dir: dir} do
    uncertain = Store.stage(dir, %{"text" => "uncertain"})
    Store.transition(dir, uncertain["id"], "pending", "publishing")
    Store.transition(dir, uncertain["id"], "publishing", "uncertain")

    held = Store.stage(dir, %{"text" => "held"})
    assert Store.claim_automatic(dir, held) == {:error, :unresolved}

    rejected = Store.transition(dir, uncertain["id"], "uncertain", "rejected")
    assert rejected["status"] == "rejected"
    assert Enum.find(Store.drafts(dir), &(&1["id"] == uncertain["id"]))["status"] == "rejected"

    assert {:ok, claimed} = Store.claim_automatic(dir, held)
    assert claimed["status"] == "publishing"

    assert_raise Error, fn ->
      Store.transition(dir, uncertain["id"], "uncertain", "pending")
    end
  end

  test "legacy live state loads without an automatic-attempt field", %{dir: dir} do
    item = Store.stage(dir, %{"text" => "legacy"})
    path = Path.join(dir, "state.json")
    state = path |> File.read!() |> Jason.decode!() |> Map.delete("automatic")
    File.write!(path, Jason.encode!(state))

    assert hd(Store.drafts(dir))["id"] == item["id"]
    assert {:ok, _claimed} = Store.claim_automatic(dir, item)
  end

  test "automatic claim is atomic and a fresh publication lease is preserved", %{dir: dir} do
    item = Store.stage(dir, %{"text" => "once"})

    results =
      1..12
      |> Task.async_stream(
        fn _ -> Store.claim_automatic(dir, item) end,
        max_concurrency: 12
      )
      |> Enum.to_list()

    assert Enum.count(results, &match?({:ok, {:ok, _}}, &1)) == 1
    assert Enum.count(results, &(&1 == {:ok, {:error, :unavailable}})) == 11
    assert hd(Store.drafts(dir))["status"] == "publishing"
  end

  test "pending drafts can be replaced and automatic budget is visible", %{dir: dir} do
    item = Store.stage(dir, pending_draft("hello"))
    budget = Store.automatic_budget(dir)
    assert budget.remaining == 5
    refute budget.frozen

    updated = Store.replace_pending(dir, item["id"], %{"text" => "hello there"})
    assert updated["text"] == "hello there"
    assert hd(Store.drafts(dir))["text"] == "hello there"

    Store.transition(dir, item["id"], "pending", "publishing")
    assert Store.automatic_budget(dir).frozen
    assert_raise Error, fn -> Store.replace_pending(dir, item["id"], %{"text" => "too late"}) end
  end

  test "replace_pending re-validates inside the store lock", %{dir: dir} do
    item = Store.stage(dir, pending_draft("hello"))

    assert_raise Error, fn ->
      Store.replace_pending(dir, item["id"], %{"text" => "hello\u0001there"})
    end

    assert hd(Store.drafts(dir))["text"] == "hello"
  end

  test "replace_pending updater can read blocked accounts from locked state", %{dir: dir} do
    item = Store.stage(dir, pending_draft("hello"))
    Store.block(dir, "alice")

    updated =
      Store.replace_pending(dir, item["id"], fn draft, state ->
        assert "alice" in state["blocked"]
        Map.put(draft, "text", "hello there")
      end)

    assert updated["text"] == "hello there"
  end

  defp pending_draft(text) do
    %{
      "platform" => "mastodon",
      "account" => "acct",
      "text" => text,
      "action" => "manual",
      "visibility" => "public",
      "language" => "en"
    }
  end
end
