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

  test "control commands refuse extras, blank edits, and most control characters" do
    assert_raise Error, fn -> Control.decode!("not-json") end
    assert_raise Error, fn -> Control.decode!(~s({"action":"publish"})) end
    assert_raise Error, fn -> Control.decode!(~s({"action":"edit","text":"   "})) end

    assert_raise Error, fn ->
      Control.decode!(Jason.encode!(%{"action" => "edit", "text" => "ok" <> <<1>>}))
    end
    assert Control.decode!(~s({"action":"edit","text":"keep\\ttabs"}))["text"] == "keep\ttabs"
  end
end
