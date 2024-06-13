defmodule Peri.MixProject do
  use Mix.Project

  @version "0.1.4"
  @source_url "https://github.com/zoedsoupe/peri"

  def project do
    [
      app: :peri,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:ex_doc, "~> 0.14", only: :dev, runtime: false}]
  end

  defp description do
    "A Plug'n Play schema validator library, focused on raw data structures"
  end

  defp package do
    [
      name: "peri",
      files: ~w(lib .formatter.exs LICENSE README.md),
      links: %{"GitHub" => @source_url},
      licenses: ["MIT"],
      main_module: "Peri"
    ]
  end
end
