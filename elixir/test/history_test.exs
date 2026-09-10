defmodule ChorusDraft.HistoryTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias ChorusDraft.{CLI, Store}

  setup do
    base = Path.join(System.tmp_dir!(), "chorus-history-#{System.unique_integer([:positive])}")
    dir = Path.join([base, "data", String.duplicate("a", 24)]) |> Store.new()
    on_exit(fn -> File.rm_rf!(base) end)
    %{base: base, dir: dir}
  end

  test "expiry preserves pending, uncertain and safety state", %{base: base, dir: dir} do
    for status <- ["published", "rejected", "pending", "uncertain"] do
      item = Store.stage(dir, %{"text" => status})

      Store.transaction(dir, fn state ->
        old = DateTime.utc_now() |> DateTime.add(-11 * 86400) |> DateTime.to_iso8601()

        drafts =
          Enum.map(state["drafts"], fn d ->
            if d["id"] == item["id"],
              do: Map.merge(d, %{"created_at" => old, "status" => status}),
              else: d
          end)

        {nil, Map.put(state, "drafts", drafts)}
      end)
    end

    Store.block(dir, "blocked.example")
    recent = Store.stage(dir, %{"text" => "recent publication"}, source: "source-id")
    Store.transition(dir, recent["id"], "pending", "publishing")
    completed = Store.transition(dir, recent["id"], "publishing", "published")
    assert {:ok, _, _} = DateTime.from_iso8601(completed["finished_at"])
    assert [^completed] = Store.history(base)

    assert Enum.sort(Enum.map(Store.drafts(dir), & &1["status"])) == [
             "pending",
             "published",
             "uncertain"
           ]

    assert Store.blocked?(dir, "blocked.example")
    assert Store.seen?(dir, "source-id")
  end

  test "history is local and retention starts at publication", %{base: base, dir: dir} do
    draft = Store.stage(dir, %{"text" => "retained"})

    Store.transaction(dir, fn state ->
      old = DateTime.utc_now() |> DateTime.add(-20 * 86400) |> DateTime.to_iso8601()
      {nil, put_in(state, ["drafts", Access.at(0), "created_at"], old)}
    end)

    Store.transition(dir, draft["id"], "pending", "publishing")
    Store.transition(dir, draft["id"], "publishing", "published")
    output = capture_io(fn -> assert CLI.run(["bluesky", "history", "--base", base]) == 0 end)
    assert [%{"text" => "retained"}] = Jason.decode!(output)
  end

  test "history is a lock-free read that never mutates state", %{base: base, dir: dir} do
    stale = Store.stage(dir, %{"text" => "stale publication"})
    Store.transition(dir, stale["id"], "pending", "publishing")
    recent = Store.stage(dir, %{"text" => "recent publication"})
    Store.transition(dir, recent["id"], "pending", "publishing")
    Store.transition(dir, recent["id"], "publishing", "published")
    old_pub = Store.stage(dir, %{"text" => "old publication"})
    Store.transition(dir, old_pub["id"], "pending", "publishing")
    Store.transition(dir, old_pub["id"], "publishing", "published")

    Store.transaction(dir, fn state ->
      old = DateTime.utc_now() |> DateTime.add(-11 * 86_400) |> DateTime.to_iso8601()

      drafts =
        Enum.map(state["drafts"], fn draft ->
          cond do
            draft["id"] == stale["id"] ->
              Map.put(draft, "claimed_at", System.system_time(:second) - 301)

            draft["id"] == old_pub["id"] ->
              draft |> Map.put("created_at", old) |> Map.put("finished_at", old)

            true ->
              draft
          end
        end)

      {nil, Map.put(state, "drafts", drafts)}
    end)

    # In memory, history recovers the stale publication and prunes the old one;
    # on disk, nothing may change and no lock file may appear.
    path = Path.join(dir, "state.json")
    File.rm!(Path.join(dir, "state.lock"))
    before = File.read!(path)

    assert [%{"text" => "recent publication"}] = Store.history(base)
    refute File.exists?(Path.join(dir, "state.lock"))
    assert File.read!(path) == before
  end

  test "history refuses linked base and data ancestors", %{base: base, dir: dir} do
    if ChorusDraft.Platform.os() != "windows" do
      linked = base <> "-link"
      File.ln_s!(base, linked)
      on_exit(fn -> File.rm!(linked) end)
      assert_raise ChorusDraft.Error, fn -> Store.history(linked) end

      assert_raise ChorusDraft.Error, fn ->
        Store.new(Path.join([linked, "data", Path.basename(dir)]))
      end

      assert File.dir?(dir)
    end
  end
end
