defmodule Mix.Tasks.Community.Export do
  use Mix.Task

  @shortdoc "Export weekly community candidates for manual operator review"

  @impl true
  def run(arguments) do
    {options, rest, invalid} = OptionParser.parse(arguments, strict: [output: :string])

    if rest != [] or invalid != [],
      do: Mix.raise("Usage: mix community.export [--output /private/path.csv]")

    Mix.Task.run("app.start")

    case EverydayTrust.Community.Export.csv() do
      {:ok, csv} ->
        case options[:output] do
          nil ->
            IO.binwrite(csv)

          path ->
            File.open!(path, [:write, :exclusive, :binary], fn file ->
              File.chmod!(path, 0o600)
              IO.binwrite(file, csv)
            end)
        end

      {:error, :disabled} ->
        Mix.raise("COMMUNITY_REPORTS_ENABLED must be enabled for an operator export")
    end
  end
end
