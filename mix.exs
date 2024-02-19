defmodule MixLfe.MixProject do
  use Mix.Project

  @version "0.3.0"

  def project do
    [
      app: :mix_lfe,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: "A LFE compiler for Mix",
      compilers: Mix.compilers() ++ [:lfe],
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_ref: "v#{@version}",
        source_url: "https://github.com/lfe/mix"
      ],
      package: package(),
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: ["lfe.test": :test]
    ]
  end

  def application do
    [extra_applications: [:logger, :eunit]]
  end

  def package do
    %{
      licenses: ["Apache 2"],
      links: %{"GitHub" => "https://github.com/lfe/mix"},
      maintainers: ["Nikolay Tsvetinov (Meddle)", "John Goff"]
    }
  end

  def deps do
    [
      {:lfe, "~> 2.1",
       compile: "make compile install-include install-beam install-bin PREFIX=$ERL_LIBS/lfe",
       override: true},
      {:ltest, "~> 0.13.6"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
