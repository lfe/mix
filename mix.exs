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
        source_url: "https://github.com/meddle0x53/mix_lfe"
      ],
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def package do
    %{
      licenses: ["Apache 2"],
      links: %{"GitHub" => "https://github.com/meddle0x53/mix_lfe"},
      maintainers: ["Nikolay Tsvetinov (Meddle)"]
    }
  end

  def deps do
    [
      {:lfe, "~> 2.1.3", manager: :make},
      {:ltest, github: "John-Goff/ltest", branch: "release/0.13.x"},
      {:erlang_color, "~> 1.0"},
      # {:lutil, "~> 0.14.3"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
