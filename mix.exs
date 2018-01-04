defmodule IntelHex.MixProject do
  use Mix.Project

  def project do
    [
      app: :intel_hex,
      version: "0.1.0",
      description: "Decode Intel Hex formatted files",
      package: package(),
      elixir: "~> 1.4",
      source_url: "https://github.com/fhunleth/intel_hex",
      docs: [extras: ["README.md"]],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp package() do
    [
      maintainers: ["Frank Hunleth"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/fhunleth/intel_hex"}
    ]
  end

end
