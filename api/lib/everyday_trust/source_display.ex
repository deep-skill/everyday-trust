defmodule EverydayTrust.SourceDisplay do
  use GenServer

  alias EverydayTrust.Domain

  @ttl 3_600_000
  @limit 1_000
  @fields ~w(domain hostname final_hostname report_url status checked_at source visibility scanned_at scope cached)

  def start_link(options \\ []), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)

  def put(id, result) do
    metadata =
      result
      |> Map.get("url_scans", [])
      |> Enum.take(5)
      |> Enum.flat_map(fn scan ->
        case report_url(scan["report_url"]) do
          nil -> []
          url -> [{url, Map.take(scan, ["page_title", "brands"])}]
        end
      end)
      |> Map.new()

    GenServer.call(__MODULE__, {:put, id, metadata})
    :ok
  catch
    :exit, _ -> :ok
  end

  def restore(id, result) do
    metadata = GenServer.call(__MODULE__, {:get, id})

    if Map.has_key?(result, "url_scans") do
      Map.update!(result, "url_scans", fn scans ->
        Enum.map(scans, fn scan ->
          Map.merge(scan, Map.get(metadata, scan["report_url"], %{}))
        end)
      end)
    else
      result
    end
  catch
    :exit, _ -> result
  end

  def sanitize(result) do
    if Map.has_key?(result, "url_scans") do
      Map.update!(result, "url_scans", fn scans ->
        scans
        |> Enum.take(5)
        |> Enum.map(fn scan ->
          scan
          |> Map.take(@fields)
          |> Map.put("domain", domain(scan["domain"] || scan["hostname"]))
          |> Map.put("hostname", domain(scan["hostname"]))
          |> Map.put("final_hostname", domain(scan["final_hostname"]))
          |> Map.put("report_url", report_url(scan["report_url"]))
        end)
      end)
    else
      result
    end
  end

  @impl true
  def init(_) do
    Process.send_after(self(), :expire, 60_000)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, id, metadata}, _from, state) do
    now = System.monotonic_time(:millisecond)
    state = Map.reject(state, fn {_, {expires, _}} -> expires <= now end)

    state =
      if map_size(state) >= @limit and not Map.has_key?(state, id),
        do: Map.delete(state, state |> Enum.min_by(fn {_, {expires, _}} -> expires end) |> elem(0)),
        else: state

    {:reply, :ok, Map.put(state, id, {now + @ttl, metadata})}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    case state[id] do
      {expires, metadata} ->
        if expires > System.monotonic_time(:millisecond),
          do: {:reply, metadata, state},
          else: {:reply, %{}, Map.delete(state, id)}

      _ -> {:reply, %{}, state}
    end
  end

  @impl true
  def handle_info(:expire, state) do
    now = System.monotonic_time(:millisecond)
    Process.send_after(self(), :expire, 60_000)
    {:noreply, Map.reject(state, fn {_, {expires, _}} -> expires <= now end)}
  end

  defp domain(value) when is_binary(value), do: Domain.registrable_domain(value)
  defp domain(_), do: nil

  defp report_url(value) when is_binary(value) do
    case Regex.run(~r|\Ahttps://urlscan\.io/result/([0-9a-fA-F-]{36})/\z|, value) do
      [_, uuid] ->
        case Ecto.UUID.cast(uuid) do
          {:ok, normalized} -> "https://urlscan.io/result/#{normalized}/"
          _ -> nil
        end

      _ -> nil
    end
  end

  defp report_url(_), do: nil
end
