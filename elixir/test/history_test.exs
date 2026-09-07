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

  @tag :tmp_dir
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
