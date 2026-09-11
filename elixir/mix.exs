defmodule ChorusDraft.MixProject do
  use Mix.Project

  def project do
    [
      app: :chorus_draft,
      version: "0.54.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(),
      escript: [main_module: ChorusDraft.CLI, name: "chorusdraft"],
      deps: [{:jason, "~> 1.4.5"}, {:websockex, "== 0.5.1"}, {:mint, "== 1.10.0"}],
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:crypto, :public_key, :ssl]]
  end

  # Guard is verified against the signature recorded for the compiled Guard
  # modules, so anything that runs or packages Guard signs it first. A release
  # signs with CHORUSDRAFT_GUARD_SIGNING_KEY; without one these builds are
  # unofficial and say so through a development key.
  defp aliases do
    [
      test: ["guard.sign --development", "test"],
      "escript.build": ["guard.sign --development", "escript.build"]
    ]
  end

  defp elixirc_paths do
    paths = ["lib"]
    if File.dir?(Path.expand("guard/lib", __DIR__)), do: paths ++ ["guard/lib"], else: paths
  end
end
