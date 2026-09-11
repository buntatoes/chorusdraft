# Offline desktop integration fixture: replace HTTP only in a temporary escript.
[{module, beam}] = Code.compile_string("""
defmodule ChorusDraft.HTTP do
  def validate_url!(url, _opts \\\\ []), do: URI.parse(url)
  def request(_method, url, opts \\\\ []) do
    cond do
      String.ends_with?(url, "com.atproto.server.createSession") ->
        if get_in(opts[:body], ["password"]) != "desktop-fixture-password", do: raise("GUI credentials were not passed")
        IO.puts("Credential check: " <> opts[:body]["password"])
        %{"did" => "did:plc:desktop", "accessJwt" => "fixture-access", "refreshJwt" => "fixture-refresh"}
      String.ends_with?(url, "app.bsky.feed.getPosts") ->
        %{
          "posts" => [
            %{
              "uri" => "at://did:plc:alice/app.bsky.feed.post/fixture",
              "cid" => "bafy-fixture",
              "author" => %{"did" => "did:plc:alice", "handle" => "alice.test"},
              "record" => %{"text" => "public source"}
            }
          ]
        }
      String.ends_with?(url, "com.atproto.repo.createRecord") ->
        File.write!(Path.join(System.fetch_env!("CHORUSDRAFT_ROOT"), "published.txt"), opts[:body]["record"]["text"])
        %{"uri" => "at://did:plc:desktop/app.bsky.feed.post/fixture"}
      true -> raise("Unexpected fixture HTTP request")
    end
  end
end
""")
{:ok, sections} = :escript.extract(~c"chorusdraft", [])
{:archive, archive} = List.keyfind(sections, :archive, 0)
{:ok, files} = :zip.extract(archive, [:memory])
target = Atom.to_string(module) <> ".beam"
unless Enum.count(files, fn {name, _} -> Path.basename(List.to_string(name)) == target end) == 1,
  do: raise("Expected exactly one HTTP module in the test escript")
files = Enum.map(files, fn {name, data} ->
  if Path.basename(List.to_string(name)) == target,
    do: {name, beam}, else: {name, data}
end)
{:ok, {_, archive}} = :zip.create(~c"fixture.zip", files, [:memory])
sections = List.keyreplace(sections, :archive, 0, {:archive, archive})
:ok = :escript.create(System.argv() |> hd() |> String.to_charlist(), sections)
