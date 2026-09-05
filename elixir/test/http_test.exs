defmodule ChorusDraft.HTTPTest do
  use ExUnit.Case, async: true
  alias ChorusDraft.{Error, HTTP, HTTPError}

  defp server(response, fun) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(listener)
    parent = self()
    task = Task.async(fn ->
      {:ok, socket} = :gen_tcp.accept(listener, 5_000)
      request = headers(socket, "")
      send(parent, {:request, request})
      :gen_tcp.send(socket, response)
      :gen_tcp.close(socket)
      case :gen_tcp.accept(listener, 400) do
        {:ok, extra} ->
          send(parent, :unexpected_retry)
          :gen_tcp.close(extra)
        {:error, :timeout} -> :ok
      end
    end)
    try do
      fun.("http://127.0.0.1:#{port}")
      Task.await(task, 6_000)
      refute_received :unexpected_retry
    after
      :gen_tcp.close(listener)
    end
  end

  defp headers(socket, data) do
    if String.contains?(data, "\r\n\r\n") do
      data
    else
      {:ok, chunk} = :gen_tcp.recv(socket, 0, 5_000)
      headers(socket, data <> chunk)
    end
  end

  test "JSON requests encode query and body without redirect or retry machinery" do
    server("HTTP/1.1 200 OK\r\nContent-Length: 11\r\n\r\n{\"ok\":true}", fn url ->
      assert HTTP.request(:post, url <> "/api", local: true, query: %{q: "elixir & ruby"}, body: %{text: "hello"}) == %{"ok" => true}
      assert_received {:request, request}
      assert request =~ "POST /api?q=elixir+%26+ruby HTTP/1.1"
      assert String.downcase(request) =~ "content-type: application/json"
    end)
  end

  test "503 Retry-After never resends a publication" do
    server("HTTP/1.1 503 Unavailable\r\nRetry-After: 0\r\nContent-Length: 0\r\n\r\n", fn url ->
      assert_raise HTTPError, fn -> HTTP.request(:post, url, local: true, body: %{text: "once"}) end
    end)
  end

  test "redirects do not forward credentials" do
    server("HTTP/1.1 302 Found\r\nLocation: https://example.org/secret\r\nContent-Length: 0\r\n\r\n", fn url ->
      error = assert_raise HTTPError, fn -> HTTP.request(:get, url, local: true, headers: %{authorization: "secret"}) end
      refute error.message =~ "secret"
    end)
  end

  test "oversized responses are rejected from headers before allocation" do
    server("HTTP/1.1 201 Created\r\nContent-Length: 999999999\r\n\r\n", fn url ->
      assert_raise Error, fn -> HTTP.request(:post, url, local: true, body: %{}) end
    end)
  end

  test "truncated and malformed JSON responses do not expose content or retry" do
    for response <- ["HTTP/1.1 201 Created\r\nContent-Length: 30\r\n\r\nSECRET", "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nSECRET"] do
      server(response, fn url ->
        error = assert_raise Error, fn -> HTTP.request(:post, url, local: true, body: %{}) end
        refute error.message =~ "SECRET"
      end)
    end
  end

  test "chunked response size is bounded without trusting content-length" do
    chunk = String.duplicate("x", 4 * 1024 * 1024 + 1)
    response = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" <> Integer.to_string(byte_size(chunk), 16) <> "\r\n" <> chunk <> "\r\n0\r\n\r\n"
    server(response, fn url ->
      assert_raise Error, fn -> HTTP.request(:get, url, local: true) end
    end)
  end
end
