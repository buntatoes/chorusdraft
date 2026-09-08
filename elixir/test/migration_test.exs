defmodule ChorusDraft.MigrationTest do
  use ExUnit.Case
  import Bitwise
  alias ChorusDraft.{Error, Platform, Runner, Setup, Store, TestClient}

  setup do
    root = Path.join(System.tmp_dir!(), "migration-#{System.unique_integer([:positive])}")
    source = Store.new(Path.join(root, "source"))
    destination = Store.new(Path.join(root, "destination"))
    runner = Runner.new(%TestClient{}, source, "mastodon", %{})
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root, source: source, destination: destination, runner: runner}
  end

  test "compatible import preserves identity, history and unresolved publications", %{
    source: source,
    destination: destination,
    runner: runner
  } do
    draft = Runner.manual(runner, "Already reviewed elsewhere")
    Store.transition(source, draft["id"], "pending", "publishing")
    Store.block(source, "no-contact")

    Store.stage(source, Runner.draft(runner, "A pending draft", "ai_generated"),
      source: "seen-post",
      unsolicited: true
    )

    path = Path.join(source, "state.json")
    before = File.read!(path)

    assert Store.import_state(
             destination,
             path,
             "mastodon",
             TestClient.account_key(runner.client)
           ) == 2

    assert File.read!(path) == before
    [imported, pending] = Store.drafts(destination)
    assert imported["status"] == "uncertain"
    assert imported["id"] == draft["id"]
    assert imported["record_key"] == draft["record_key"]
    assert pending["status"] == "pending"
    assert Store.seen?(destination, "seen-post")
    assert Store.blocked?(destination, "no-contact")

    assert_raise Error, fn ->
      Store.import_state(destination, path, "mastodon", TestClient.account_key(runner.client))
    end

    assert_raise Error, fn ->
      Store.transition(destination, imported["id"], "uncertain", "pending")
    end
  end

  test "imports a legacy ChorusDraft state fixture", %{
    root: root,
    destination: destination
  } do
    fixture = Path.join(root, "legacy-fixture")
    File.mkdir_p!(fixture)
    path = Path.join(fixture, "state.json")
    now = System.system_time(:second)

    state = %{
      "drafts" => [
        %{
          "id" => "12345678-1234-1234-1234-123456789abc",
          "record_key" => "2222222222222",
          "created_at" => "2026-09-06T00:00:00.000000Z",
          "status" => "pending",
          "platform" => "mastodon",
          "account" => "https://example.org:me",
          "text" => "Legacy draft",
          "action" => "ai_generated",
          "visibility" => "public",
          "language" => "en",
          "author" => "alice"
        }
      ],
      "seen" => ["legacy-seen"],
      "authors" => %{"alice" => now},
      "daily" => [now],
      "blocked" => ["no-contact"]
    }

    File.write!(path, Jason.encode!(state))
    original = File.read!(path)
    assert Store.import_state(destination, path, "mastodon", "https://example.org:me") == 1
    assert File.read!(path) == original
    assert hd(Store.drafts(destination))["text"] == "Legacy draft"
    assert Store.seen?(destination, "legacy-seen")
    assert Store.blocked?(destination, "no-contact")
    refute Store.available?(destination, author: "alice", unsolicited: true)
  end

  test "cross-account and malformed imports leave destination empty", %{
    source: source,
    destination: destination,
    runner: runner
  } do
    Runner.manual(runner, "hello")
    path = Path.join(source, "state.json")

    assert_raise Error, fn ->
      Store.import_state(destination, path, "mastodon", "another-account")
    end

    File.write!(
      path,
      Jason.encode!(%{
        "drafts" => [],
        "seen" => [123],
        "blocked" => [],
        "daily" => [],
        "authors" => %{}
      })
    )

    assert_raise Error, fn ->
      Store.import_state(destination, path, "mastodon", "another-account")
    end

    assert Store.drafts(destination) == []
  end

  test "state readers reject symlinks and directories instead of resetting history", %{
    source: source,
    destination: destination
  } do
    File.mkdir!(Path.join(source, "state.json"))
    assert_raise Error, fn -> Store.drafts(source) end

    case File.ln_s(Path.join(source, "state.json"), Path.join(destination, "state.json")) do
      :ok ->
        assert_raise Error, fn -> Store.drafts(destination) end

      {:error, reason} ->
        if Platform.os() == "windows" and reason in [:eacces, :eperm],
          do: :ok,
          else: flunk("Could not create test symlink: #{inspect(reason)}")
    end
  end

  test "kernel locking prevents concurrent reviewers claiming the same draft", %{source: source} do
    item = Store.stage(source, %{"text" => "once"})

    results =
      1..12
      |> Task.async_stream(
        fn _ ->
          try do
            Store.transition(source, item["id"], "pending", "publishing", expected: item)
            :claimed
          rescue
            Error -> :unavailable
          end
        end,
        max_concurrency: 12
      )
      |> Enum.to_list()

    assert Enum.count(results, &(&1 == {:ok, :claimed})) == 1
    assert Enum.count(results, &(&1 == {:ok, :unavailable})) == 11
  end

  test "kernel lock releases when the transaction process is killed", %{source: source} do
    parent = self()

    pid =
      spawn(fn ->
        Store.transaction(source, fn state ->
          send(parent, :locked)

          receive do
            :finish -> {nil, state}
          end
        end)
      end)

    assert_receive :locked, 2_000
    Process.exit(pid, :kill)
    assert Store.stage(source, %{"text" => "recovered"})
  end

  test "setup is offline, private and preserves existing user files", %{root: root} do
    base = Path.join(root, "setup")
    File.mkdir_p!(Path.join(base, "config"))

    for file <- [".env", "config/target_accounts.txt", "config/do_not_contact.txt"] do
      File.write!(Path.join(base, file <> ".example"), "example")
    end

    Setup.run(base)
    File.write!(Path.join(base, ".env"), "KEEP=$(literal)")
    Setup.run(base)
    assert File.read!(Path.join(base, ".env")) == "KEEP=$(literal)"

    if Platform.os() != "windows",
      do: assert((File.stat!(Path.join(base, ".env")).mode &&& 0o777) == 0o600)
  end
end
