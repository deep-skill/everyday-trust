defmodule EverydayTrust.Cleanup do
  use GenServer
  def start_link(_), do: GenServer.start_link(__MODULE__, nil)

  def init(_),
    do:
      (
        Process.send_after(self(), :clean, 60_000)
        {:ok, nil}
      )

  def handle_info(:clean, state) do
    try do
      EverydayTrust.Cases.cleanup()
    rescue
      _ -> :ok
    after
      Process.send_after(self(), :clean, 60_000)
    end

    {:noreply, state}
  end
end
