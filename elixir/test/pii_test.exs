defmodule ChorusDraft.PIITest do
  use ExUnit.Case, async: true
  alias ChorusDraft.{AI, Error, PII, Runner, TestClient, TestHTTP}

  test "PII and common obfuscations are detected without echoing them in errors" do
    for value <- [
          "alice@example.org",
          "alice [at] example [dot] org",
          "alice (at) example (dot) org",
          "alice at example dot org",
          "alice @ example.org",
          "ａｌｉｃｅ＠ｅｘａｍｐｌｅ．ｏｒｇ",
          "alice\u200B@example.org",
          "+44 20 7946 0958",
          "(312) 555-0199",
          "١٢٣٤٥٦٧٨٩",
          "123–45–6789",
          "4111 1111 1111 1111",
          "123 Example Terrace",
          "PO Box 42",
          "DOB: 01/02/1990",
          "passport number: AB12345",
          "40.123456, -70.123456",
          "sk-proj-" <> String.duplicate("x", 30)
        ] do
      assert PII.sensitive?(value), value
      error = assert_raise Error, fn -> PII.validate!(value) end
      refute Exception.message(error) =~ value
      refute PII.sensitive?(PII.redact(value))
    end
  end

  test "ordinary discussion and public social mentions remain usable" do
    for text <- [
          "Ruby 4.0 and Elixir 1.15 run on Linux.",
          "The build took 42 seconds.",
          "@alice@example.org A calm observation.",
          "@alice.bsky.social A calm observation.",
          "Ask @third-party.example about this deployment"
        ] do
      refute PII.sensitive?(text)
    end
  end

  test "nested context is redacted before an AI request" do
    TestHTTP.set_responses([%{"response" => "A calm observation."}])

    data = %{
      "post" => "Call 312-555-0199",
      "thread" => [%{"text" => "alice [at] example.org"}]
    }

    assert AI.generate(%{}, "Draft", data, 300, http: TestHTTP) == "A calm observation."
    [{:post, _, options}] = TestHTTP.calls()
    [_, user] = options[:body]["messages"]
    context = Jason.decode!(user["content"])["untrusted_context"]
    assert context["post"] == "Call [REDACTED]"
    assert context["thread"] == [%{"text" => "[REDACTED]"}]
    assert data["post"] == "Call 312-555-0199"
  end

  test "provider output with PII is rejected even in review mode" do
    TestHTTP.set_responses([%{"response" => "Email alice@example.org"}])
    assert_raise Error, fn -> AI.generate(%{}, "Draft", %{}, 300, http: TestHTTP) end
  end

  test "saved AI drafts and content warnings are screened again before publication" do
    runner = Runner.new(%TestClient{}, nil, "mastodon", %{})
    item = Runner.draft(runner, "A calm observation.", "ai_generated")

    for draft <- [
          Map.put(item, "text", "Call 312-555-0199"),
          Map.put(item, "cw", "DOB: 01/02/1990")
        ] do
      assert_raise Error, fn -> Runner.validate_draft!(runner, draft) end
    end
  end
end
