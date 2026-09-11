defmodule ChorusDraft.MixProject do
  use Mix.Project

  def project do
    [
      app: :chorus_draft,
      version: "0.54.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(),
      escript: [main_module: ChorusDraft.CLI, name: "chorusdraft"],
      deps: [{:jason, "~> 1.4.5"}, {:websockex, "== 0.5.1"}, {:mint, "== 1.10.0"}]
    ]
  end

  def application do
    [extra_applications: [:crypto, :public_key, :ssl]]
  end

  defp elixirc_paths do
    paths = ["lib"]
    if File.dir?(Path.expand("guard/lib", __DIR__)), do: paths ++ ["guard/lib"], else: paths
  end
end
