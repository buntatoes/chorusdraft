Code.require_file("lib/chorus_draft.ex", __DIR__)
Code.require_file("lib/chorus_draft/setup.ex", __DIR__)

case System.argv() do
  [platform] when platform in ["bluesky", "mastodon"] ->
    ChorusDraft.Setup.run(Path.join(__DIR__, platform))
  _ -> raise "Usage: elixir setup.exs bluesky|mastodon"
end
