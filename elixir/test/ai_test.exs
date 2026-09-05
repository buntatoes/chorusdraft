defmodule ChorusDraft.AITest do
  use ExUnit.Case
  alias ChorusDraft.{AI, Error, TestHTTP}

  test "OpenAI-compatible requests separate instructions from untrusted context" do
    TestHTTP.set_responses([%{"choices" => [%{"message" => %{"content" => "A careful draft."}}]}])
    assert AI.generate(%{}, "Draft a reply", %{"post" => "source"}, 300, http: TestHTTP) == "A careful draft."
    [{:post, _, options}] = TestHTTP.calls()
    [system, user] = options[:body]["messages"]
    assert system["role"] == "system"
    assert Jason.decode!(user["content"])["untrusted_context"] == %{"post" => "source"}
    assert options[:local]
  end

  test "Ollama native generation is non-streaming and carries a separate system prompt" do
    TestHTTP.set_responses([%{"response" => "A careful draft."}])
    AI.generate(%{"AI_PROVIDER" => "ollama", "LOCAL_LLM_URL" => "http://localhost:11434/api/generate"}, "Draft", %{}, 300, http: TestHTTP)
    [{:post, _, options}] = TestHTTP.calls()
    assert options[:body]["stream"] == false
    assert options[:body]["system"] == AI.system_prompt()
  end

  test "Gemini uses a header for credentials and rejects missing or unsafe output" do
    env = %{"AI_PROVIDER" => "gemini", "GEMINI_API_KEY" => "fixture-secret", "GEMINI_MODEL" => "fixture-model"}
    TestHTTP.set_responses([%{"candidates" => [%{"content" => %{"parts" => [%{"text" => "A careful draft."}]}}]}])
    assert AI.generate(env, "Draft", %{}, 300, http: TestHTTP) == "A careful draft."
    [{:post, url, options}] = TestHTTP.calls()
    refute url =~ "fixture-secret"
    assert options[:headers]["x-goog-api-key"] == "fixture-secret"
    for response <- [%{}, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => "You are an idiot"}]}}]}] do
      TestHTTP.set_responses([response])
      assert_raise Error, fn -> AI.generate(env, "Draft", %{}, 300, http: TestHTTP) end
    end
  end
end
