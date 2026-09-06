defmodule ChorusDraft.ClientTest do
  use ExUnit.Case
  alias ChorusDraft.{Error, TestHTTP}
  alias ChorusDraft.Clients.{Bluesky, Mastodon}

  setup do
    TestHTTP.set_responses([])
    :ok
  end

  defp mastodon do
    Mastodon.new(
      %{"MASTODON_API_BASE_URL" => "https://example.org", "MASTODON_ACCESS_TOKEN" => "secret"},
      http: TestHTTP
    )
  end

  defp bluesky do
    Bluesky.new(%{"BLUESKY_HANDLE" => "alice.test", "BLUESKY_APP_PASSWORD" => "secret"},
      http: TestHTTP
    )
  end

  test "Mastodon discards restricted message bodies during normalization" do
    post =
      Mastodon.normalize(%{
        "id" => "1",
        "content" => "SECRET",
        "visibility" => "direct",
        "spoiler_text" => "SECRET CW"
      })

    refute Jason.encode!(post) =~ "SECRET"
  end

  test "Mastodon rechecks reply visibility before publication" do
    TestHTTP.set_responses([%{"id" => "1", "visibility" => "direct"}])
    draft = %{"id" => "draft", "text" => "Hello", "visibility" => "public", "reply_to" => "1"}
    assert_raise Error, fn -> Mastodon.publish(mastodon(), draft) end
    assert Enum.map(TestHTTP.calls(), &elem(&1, 0)) == [:get]
  end

  test "Mastodon uses idempotency and preserves unlisted replies" do
    TestHTTP.set_responses([%{"id" => "1", "visibility" => "unlisted"}, %{"id" => "2"}])
    draft = %{"id" => "draft", "text" => "Hello", "visibility" => "public", "reply_to" => "1"}
    Mastodon.publish(mastodon(), draft)
    {_method, _url, opts} = List.last(TestHTTP.calls())
    assert opts[:body]["visibility"] == "unlisted"
    assert opts[:headers]["Idempotency-Key"] == "draft"
  end

  test "Bluesky reply uses current root and stable record key" do
    session = %{"did" => "did:plc:me", "accessJwt" => "access", "refreshJwt" => "refresh"}

    post = %{
      "uri" => "at://did:plc:alice/app.bsky.feed.post/abc",
      "cid" => "bafy-parent",
      "author" => %{"did" => "did:plc:alice", "handle" => "alice.test"},
      "record" => %{
        "text" => "hello",
        "reply" => %{
          "root" => %{"uri" => "at://did:plc:root/app.bsky.feed.post/root", "cid" => "bafy-root"}
        }
      }
    }

    TestHTTP.set_responses([session, %{"posts" => [post]}, %{"uri" => "posted"}])
    client = bluesky() |> Bluesky.login()

    Bluesky.publish(client, %{
      "id" => "draft",
      "record_key" => "3m2abcdefghijkl",
      "text" => "Hello",
      "created_at" => "2026-09-05T00:00:00Z",
      "visibility" => "public",
      "reply_to" => post["uri"]
    })

    {_method, _url, opts} = List.last(TestHTTP.calls())
    assert opts[:body]["rkey"] == "3m2abcdefghijkl"
    assert get_in(opts, [:body, "record", "reply", "parent", "cid"]) == "bafy-parent"
    assert get_in(opts, [:body, "record", "reply", "root", "cid"]) == "bafy-root"
  end

  test "Bluesky facet offsets use UTF-8 bytes" do
    TestHTTP.set_responses([%{"did" => "did:plc:alice"}])
    [facet | _] = Bluesky.facets(bluesky(), "🙂 @alice.test https://example.org #Elixir")
    assert facet["index"]["byteStart"] == 5
    assert facet["index"]["byteEnd"] == 16
  end
end
