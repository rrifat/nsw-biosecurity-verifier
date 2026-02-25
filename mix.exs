defmodule NswBiosecurityVerifier.MixProject do
  use Mix.Project

  def project do
    [
      app: :nsw_biosecurity_verifier,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end
end
