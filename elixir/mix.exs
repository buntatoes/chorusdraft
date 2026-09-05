defmodule ChorusDraft.MixProject do
  use Mix.Project

  def project do
    [
      app: :chorus_draft,
      version: "0.52.0-testing",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: ChorusDraft.CLI, name: "chorusdraft"],
      deps: [{:jason, "~> 1.4.5"}]
    ]
  end

  def application do
    [extra_applications: [:crypto, :inets, :public_key, :ssl]]
  end
end
