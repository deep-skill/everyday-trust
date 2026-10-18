defmodule Mix.Tasks.Trust.Ingest do
  use Mix.Task
  @shortdoc "Validate and activate a local Phishing.Database snapshot"
  def run(args) do
    {options, _, invalid} =
      OptionParser.parse(args,
        strict: [file: :string, sha256: :string, fetched_at: :string, published_at: :string]
      )

    if invalid != [] || !options[:file] || !options[:sha256] || !options[:fetched_at] ||
         !options[:published_at],
       do:
         Mix.raise("Use --file PATH --sha256 DIGEST --fetched-at ISO8601 --published-at ISO8601")

    Mix.Task.run("app.start")

    case EverydayTrust.Threats.ingest(
           options[:file],
           options[:sha256],
           options[:fetched_at],
           options[:published_at]
         ) do
      {:ok, result} -> Mix.shell().info(Jason.encode!(result))
      {:error, _} -> Mix.raise("Snapshot rejected; the previous active version is unchanged")
    end
  end
end
