defmodule IntelHex.MixProject do
  use Mix.Project

  def project do
    [
      app: :intel_hex,
      version: "0.1.0",
      elixir: "~> 1.6",
      description: "Decode Intel Hex formatted files",
      source_url: "https://github.com/fhunleth/intel_hex",
      docs: [extras: ["README.md"], main: "readme"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.18", only: [:dev, :test], runtime: false}
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
