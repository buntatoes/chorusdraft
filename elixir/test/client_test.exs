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

  test "identifier checks are anchored to the whole value" do
    assert_raise Error, fn -> Mastodon.get_post(mastodon(), "123\n") end
    assert_raise Error, fn -> Mastodon.get_post(mastodon(), "123\nx") end

    assert_raise Error, fn ->
      Bluesky.get_post(bluesky(), "at://did:plc:x/app.bsky.feed.post/abc\n")
    end

    assert TestHTTP.calls() == []
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

  test "Bluesky refreshes the session once after a 401 and retries with the new token" do
    session = %{"did" => "did:plc:me", "accessJwt" => "access", "refreshJwt" => "refresh"}
    refreshed = %{"did" => "did:plc:me", "accessJwt" => "access2", "refreshJwt" => "refresh2"}

    TestHTTP.set_responses([
      session,
      ChorusDraft.HTTPError.exception(401),
      refreshed,
      %{"posts" => []}
    ])

    client = bluesky() |> Bluesky.login()
    assert Bluesky.search(client, "elixir") == []

    calls = TestHTTP.calls()
    assert Enum.map(calls, &elem(&1, 0)) == [:post, :get, :post, :get]
    assert Enum.at(calls, 2) |> elem(1) =~ "com.atproto.server.refreshSession"
    assert (Enum.at(calls, 2) |> elem(2))[:headers]["Authorization"] == "Bearer refresh"
    assert (Enum.at(calls, 3) |> elem(2))[:headers]["Authorization"] == "Bearer access2"
  end

  test "Bluesky fails closed when a refreshed session belongs to another account" do
    session = %{"did" => "did:plc:me", "accessJwt" => "access", "refreshJwt" => "refresh"}

    hijacked = %{
      "did" => "did:plc:mallory",
      "accessJwt" => "access2",
      "refreshJwt" => "refresh2"
    }

    TestHTTP.set_responses([session, ChorusDraft.HTTPError.exception(401), hijacked])
    client = bluesky() |> Bluesky.login()

    assert_raise Error, ~r/Session account changed/, fn ->
      Bluesky.search(client, "elixir")
    end

    # No retry with the mismatched session may happen.
    assert Enum.map(TestHTTP.calls(), &elem(&1, 0)) == [:post, :get, :post]
  end
end
