defmodule ChorusDraft.MixProject do
  use Mix.Project

  def project do
    [
      app: :chorus_draft,
      version: "0.51.6",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: ChorusDraft.CLI, name: "chorusdraft"],
      deps: [{:jason, "~> 1.4.5"}, {:websockex, "== 0.5.1"}, {:mint, "== 1.10.0"}]
    ]
  end

  def application do
    [extra_applications: [:crypto, :public_key, :ssl]]
  end
end
