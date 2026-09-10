defmodule ChorusDraft.ControlTest do
  use ExUnit.Case, async: true
  alias ChorusDraft.{Control, Error}

  test "control commands accept approve, reject, quit, skip, and edit" do
    assert Control.decode!(~s({"action":"approve"})) == %{"action" => "approve"}
    assert Control.decode!(~s({"action":"reject"})) == %{"action" => "reject"}
    assert Control.decode!(~s({"action":"quit"})) == %{"action" => "quit"}
    assert Control.decode!(~s({"action":"skip"})) == %{"action" => "skip"}

    assert Control.decode!(~s({"action":"edit","text":"line one\\nline two"})) ==
             %{"action" => "edit", "text" => "line one\nline two"}
  end

  test "control commands refuse unknown actions, blank edits, and most control characters" do
    assert_raise Error, fn -> Control.decode!("not-json") end
    assert_raise Error, fn -> Control.decode!(~s({"action":"publish"})) end
    assert_raise Error, fn -> Control.decode!(~s({"action":"edit","text":"   "})) end

    assert_raise Error, fn ->
      Control.decode!(Jason.encode!(%{"action" => "edit", "text" => "ok" <> <<1>>}))
    end

    assert Control.decode!(~s({"action":"edit","text":"keep\\ttabs"}))["text"] == "keep\ttabs"
  end

  test "control commands silently drop extra fields" do
    assert Control.decode!(~s({"action":"approve","text":"ignored","extra":1})) ==
             %{"action" => "approve"}

    assert Control.decode!(~s({"action":"edit","text":"keep","position":3})) ==
             %{"action" => "edit", "text" => "keep"}
  end

  test "edit text is capped at ten thousand characters" do
    assert %{"action" => "edit", "text" => text} =
             Control.decode!(
               Jason.encode!(%{"action" => "edit", "text" => String.duplicate("x", 10_000)})
             )

    assert String.length(text) == 10_000

    assert_raise Error, fn ->
      Control.decode!(
        Jason.encode!(%{"action" => "edit", "text" => String.duplicate("x", 10_001)})
      )
    end
  end

  test "control read maps EOF and device errors to quit" do
    {:ok, empty} = StringIO.open("")

    try do
      assert Control.read(empty) == %{"action" => "quit"}
    after
      StringIO.close(empty)
    end

    path = Path.join(System.tmp_dir!(), "control-#{System.unique_integer([:positive])}.txt")
    File.write!(path, "")
    {:ok, device} = File.open(path, [:read, :binary])
    File.close(device)
    on_exit(fn -> File.rm(path) end)

    assert Control.read(device) == %{"action" => "quit"}
  end

  test "control lines are capped at 64 KiB" do
    # The line cap is 65_536 bytes excluding the newline.
    overhead = byte_size(Jason.encode!(%{"action" => "approve", "pad" => ""}))
    within = %{"action" => "approve", "pad" => String.duplicate("x", 65_536 - overhead)}
    assert byte_size(Jason.encode!(within)) == 65_536

    {:ok, ok} = StringIO.open(Jason.encode!(within) <> "\n")

    try do
      assert Control.read(ok) == %{"action" => "approve"}
    after
      StringIO.close(ok)
    end

    beyond = %{"action" => "approve", "pad" => String.duplicate("x", 65_537 - overhead)}
    {:ok, over} = StringIO.open(Jason.encode!(beyond) <> "\n")

    try do
      assert_raise Error, ~r/line limit/, fn -> Control.read(over) end
    after
      StringIO.close(over)
    end
  end

  test "control read accepts piped binaries and list-mode stdio charlists" do
    path = Path.join(System.tmp_dir!(), "control-#{System.unique_integer([:positive])}.txt")
    File.write!(path, ~s({"action":"approve"}\n{"action":"quit"}\n))
    on_exit(fn -> File.rm(path) end)

    {:ok, binary} = File.open(path, [:read, :binary])

    try do
      assert Control.read(binary) == %{"action" => "approve"}
    after
      File.close(binary)
    end

    {:ok, listed} = :file.open(String.to_charlist(path), [:read])
    :ok = :io.setopts(listed, [{:binary, false}, {:encoding, :unicode}])

    try do
      assert Control.read(listed) == %{"action" => "approve"}
    after
      :file.close(listed)
    end
  end
end
