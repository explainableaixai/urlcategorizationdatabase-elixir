defmodule URLCategorizationDatabase.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :urlcategorizationdatabase,
      version: "1.0.0",
      elixir: "~> 1.14",
      description: "Elixir client for URL Categorization Database.",
      package: package(),
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      source_url: "https://github.com/explainableaixai/urlcategorizationdatabase-elixir",
      homepage_url: "https://www.urlcategorizationdatabase.com"
    ]

  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:req, "~> 0.5"}, {:ex_doc, "~> 0.34", only: :dev, runtime: false}]

  defp package,
    do: [
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE),
      links: %{
        "Homepage" => "https://www.urlcategorizationdatabase.com",
        "GitHub" => "https://github.com/explainableaixai/urlcategorizationdatabase-elixir"
      }
    ]
end
