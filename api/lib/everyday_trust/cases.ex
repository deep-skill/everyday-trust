defmodule EverydayTrust.Profile do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "account_profiles" do
    field :issuer, :string
    field :subject, :string
    timestamps(type: :utc_datetime_usec)
  end
end

defmodule EverydayTrust.Case do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "temporary_cases" do
    field :session_hash, :string
    field :owner_id, :binary_id
    field :result, :map
    field :context, :string
    field :turns, :integer, default: 0
    field :feedback, :string
    field :kind, :string, default: "query"
    field :analysis_pending, :boolean, default: false
    field :analysis_deadline, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :max_expires_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end
end

defmodule EverydayTrust.SavedCase do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "saved_cases" do
    field :owner_id, :binary_id
    field :temporary_case_id, :binary_id
    field :result, :map
    timestamps(type: :utc_datetime_usec)
  end
end

defmodule EverydayTrust.Cases do
  import Ecto.Query
  alias EverydayTrust.{Repo, Profile, Case, SavedCase, Analysis}

  def profile(nil), do: nil

  def profile(identity) do
    now = DateTime.utc_now()

    Repo.insert!(
      %Profile{
        issuer: identity.issuer,
        subject: identity.subject,
        inserted_at: now,
        updated_at: now
      },
      on_conflict: :nothing,
      conflict_target: [:issuer, :subject]
    )

    Repo.get_by!(Profile, issuer: identity.issuer, subject: identity.subject)
  end

  def create(text, session, owner, options \\ []) do
    limits =
      [{session, owner, "analysis", if(owner, do: 25, else: 5)}] ++
        if(options[:network],
          do: [{options[:network], nil, "network", 200}, {"global", nil, "all_analyses", 1000}],
          else: []
        )

    reservation = if options[:quota_reserved], do: :ok, else: reserve(limits)

    case reservation do
      :ok ->
        base = Analysis.run(text, feed: true) |> EverydayTrust.Community.enrich()
        base =
          if options[:input_kind] == "image",
            do: base |> Map.put("input_kind", "image") |> put_in(["coverage", "image_extraction"], "completed") |> put_in(["coverage", "ai"], "not_applicable"),
            else: base
        safe_browsing = EverydayTrust.SafeBrowsing.enabled?()
        urlscan = EverydayTrust.Urlscan.enabled?()
        ai = !options[:skip_ai] && EverydayTrust.Interpreter.enabled?()
        pending = ai || safe_browsing || urlscan
        now = DateTime.utc_now()
        deadline_seconds = cond do
          urlscan -> 40
          safe_browsing -> 10
          true -> 8
        end

        base =
          if safe_browsing,
            do: put_in(base, ["coverage", "safe_browsing"], "pending"),
            else: base

        base = if urlscan, do: put_in(base, ["coverage", "urlscan"], "pending"), else: base
        base = if ai, do: put_in(base, ["coverage", "ai"], "pending"), else: base

        result =
          if pending,
            do:
              base
              |> Map.put("analysis_status", "in_progress")
              |> put_in(["coverage", "ai"], if(ai, do: "pending", else: Map.get(base["coverage"], "ai", "disabled")))
              |> abstain(),
            else: base

        kind = if options[:demo] || demo?(text), do: "demo", else: "query"

        {:ok, item} =
          Repo.transaction(fn ->
            item =
              Repo.insert!(%Case{
                session_hash: session,
                owner_id: if(owner, do: owner.id),
                kind: kind,
                result: result,
                context: Analysis.context(result),
                analysis_pending: pending,
                analysis_deadline: if(pending, do: DateTime.add(now, deadline_seconds)),
                expires_at: DateTime.add(now, 3600),
                max_expires_at: DateTime.add(now, 14_400)
              })

            unless pending, do: EverydayTrust.Metrics.complete(item)
            item
          end)

        if pending do
          model_text = EverydayTrust.Interpreter.input_text(text)
          urls = if safe_browsing || urlscan, do: EverydayTrust.Signals.extract_urls(text), else: []

          case Task.Supervisor.start_child(EverydayTrust.AnalysisTasks, fn ->
                 enriched = EverydayTrust.AsyncSources.enrich(base, model_text, urls, skip_ai: options[:skip_ai])
                 finish(item.id, enriched)
               end) do
            {:ok, _} -> :ok
            _ -> finish(item.id, EverydayTrust.AsyncSources.unavailable(result))
          end
        end

        {:ok, present(item)}

      _ ->
        {:error, 429, "quota_exceeded"}
    end
  end

  defp demo?(text),
    do:
      text in [
        "Hola mamá, cambié de número. Necesito que me hagas una transferencia urgente. Te cuento después.",
        "BANCO EJEMPLO: Tu cuenta será bloqueada hoy. Valida tu contraseña en https://acceso-banco.example/validar para evitar el bloqueo."
      ]

  def create_image(image, text, session, owner, network, options \\ []) do
    with true <- EverydayTrust.ImageInput.enabled?(),
         true <- is_binary(text) && String.length(text) <= 5_000,
         {:ok, validated} <- EverydayTrust.ImageInput.validate(image),
         limits <- [{session, owner, "analysis", if(owner, do: 25, else: 5)}, {network, nil, "network", 200}, {"global", nil, "all_analyses", 1000}, {"global", nil, "ai", 200, 1}],
         :ok <- reserve(limits, 2),
         {:ok, extracted} <- EverydayTrust.ImageInput.extract(validated),
         false <- extracted.no_text,
         combined <- String.trim(extracted.text <> "\n" <> text),
         true <- String.length(combined) > 0 && String.length(combined) <= 5_000 do
      create(combined, session, owner, network: network, demo: options[:demo], quota_reserved: true, skip_ai: true, input_kind: "image")
    else
      {:error, :too_large} -> {:error, 413, "image_too_large"}
      {:error, reason} when reason in [:invalid_image, :dimensions, :metadata] -> {:error, 400, "invalid_image"}
      {:error, _} -> {:error, 503, "image_unavailable"}
      :error -> {:error, 429, "quota_exceeded"}
      true -> {:error, 422, "image_no_text"}
      false -> if EverydayTrust.ImageInput.enabled?(), do: {:error, 422, "image_no_text"}, else: {:error, 404, "image_disabled"}
      _ -> {:error, 400, "invalid_image"}
    end
  end

  defp reserve(limits, amount \\ 1) do
    case Repo.transaction(fn ->
           Enum.each(limits, fn
             {s, o, operation, limit} ->
               unless quota(s, o, operation, limit, amount), do: Repo.rollback(:quota)
             {s, o, operation, limit, cost} ->
               unless quota(s, o, operation, limit, cost), do: Repo.rollback(:quota)
           end)
         end) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  defp abstain(result) do
    if result["verdict"] == "no_signals_detected",
      do:
        Map.merge(result, %{
          "verdict" => "inconclusive",
          "summary" => "La revisión no está completa. Confirma por otro canal antes de actuar."
        }),
      else: result
  end

  def finish(id, result) do
    result = EverydayTrust.Community.enrich(result)
    EverydayTrust.SourceDisplay.put(id, result)
    result = EverydayTrust.SourceDisplay.sanitize(result)
    result = result |> Map.put("analysis_status", "completed") |> Map.put("revision", 2)
    result = if result["coverage"]["ai"] == "completed", do: result, else: abstain(result)

    Repo.transaction(fn ->
      {count, items} =
        Repo.update_all(from(c in Case, where: c.id == ^id and c.analysis_pending, select: c),
          set: [
            result: result,
            context: Analysis.context(result),
            analysis_pending: false,
            updated_at: DateTime.utc_now()
          ]
        )

      if count == 1, do: EverydayTrust.Metrics.complete(hd(items))
    end)
  end

  defp expire_pending(item) do
    if item.analysis_pending &&
         DateTime.compare(item.analysis_deadline, DateTime.utc_now()) != :gt do
      result =
        Map.update!(item.result, "coverage", fn coverage ->
          Map.new(coverage, fn
            {key, "pending"} -> {key, "unavailable"}
            entry -> entry
          end)
        end)

      finish(item.id, result)
      Repo.get!(Case, item.id)
    else
      item
    end
  end

  def quota(session, owner, operation, limit, amount \\ 1) do
    subject = if owner, do: owner.id, else: session
    key = "#{operation}:#{Date.utc_today()}:#{subject}"

    result =
      Repo.query!(
        "INSERT INTO quota_buckets (key,count,expires_at) VALUES ($1,$4,$2) ON CONFLICT (key) DO UPDATE SET count = quota_buckets.count + $4 WHERE quota_buckets.count + $4 <= $3 RETURNING count",
        [key, DateTime.add(DateTime.utc_now(), 172_800), limit, amount]
      )

    result.num_rows == 1
  end

  def get(id, session, owner) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Case{} = item <- Repo.get(Case, id),
         true <- DateTime.compare(item.expires_at, DateTime.utc_now()) == :gt,
         true <-
           if(is_nil(item.owner_id),
             do: item.session_hash == session,
             else: owner && item.owner_id == owner.id
           ) do
      {:ok, expire_pending(item)}
    else
      _ -> {:error, 404, "not_found"}
    end
  end

  def present(item),
    do:
      EverydayTrust.SourceDisplay.restore(item.id, item.result)
      |> Map.merge(%{
        "id" => item.id,
        "expires_at" => DateTime.to_iso8601(item.expires_at),
        "community_domain" => if(item.kind == "demo", do: nil, else: EverydayTrust.Community.eligible_domain(item.result))
      })
      |> EverydayTrust.ReportActions.enrich()

  def save(id, session, owner) do
    with {:ok, item} <- get(id, session, owner) do
      if item.result["analysis_status"] != "completed" do
        {:error, 409, "analysis_in_progress"}
      else
        Repo.transaction(fn ->
          current = Repo.one!(from c in Case, where: c.id == ^item.id, lock: "FOR UPDATE")
          if current.owner_id && current.owner_id != owner.id, do: Repo.rollback(:not_found)
          Repo.update!(Ecto.Changeset.change(current, owner_id: owner.id))
          now = DateTime.utc_now()

          Repo.insert!(
            %SavedCase{
              owner_id: owner.id,
              temporary_case_id: item.id,
              result: item.result,
              inserted_at: now,
              updated_at: now
            },
            on_conflict: :nothing,
            conflict_target: [:owner_id, :temporary_case_id]
          )

          saved = Repo.get_by!(SavedCase, owner_id: owner.id, temporary_case_id: item.id)

          %{
            "id" => saved.id,
            "result" => saved.result,
            "created_at" => DateTime.to_iso8601(saved.inserted_at)
          }
        end)
        |> case do
          {:ok, result} -> {:ok, result}
          _ -> {:error, 404, "not_found"}
        end
      end
    end
  end

  def history(owner, cursor) do
    query =
      from c in SavedCase,
        where: c.owner_id == ^owner.id,
        order_by: [desc: c.inserted_at, desc: c.id],
        limit: 21

    query =
      case decode_cursor(cursor) do
        {:ok, date, id} ->
          from c in query, where: c.inserted_at < ^date or (c.inserted_at == ^date and c.id < ^id)

        _ ->
          query
      end

    all = Repo.all(query)
    rows = Enum.take(all, 20)
    next = if length(all) > 20, do: encode_cursor(List.last(rows))

    %{
      items: Enum.map(rows, fn c -> %{id: c.id, result: c.result, created_at: c.inserted_at} end),
      next_cursor: next
    }
  end

  def saved(id, owner) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %SavedCase{} = item <- Repo.get_by(SavedCase, id: id, owner_id: owner.id),
         do: {:ok, item},
         else: (_ -> {:error, 404, "not_found"})
  end

  def delete(id, owner) do
    with {:ok, item} <- saved(id, owner),
         do:
           (
             Repo.delete!(item)
             {:ok, %{deleted: true}}
           )
  end

  def feedback(id, session, owner, value) when value in ["helpful", "unhelpful"] do
    with {:ok, item} <- get(id, session, owner) do
      Repo.transaction(fn ->
        {count, _} =
          Repo.update_all(from(c in Case, where: c.id == ^item.id and is_nil(c.feedback)),
            set: [feedback: value]
          )

        if count == 1, do: EverydayTrust.Metrics.feedback(item.kind, value)
      end)

      {:ok, %{recorded: true}}
    end
  end

  def feedback(_, _, _, _), do: {:error, 400, "invalid_feedback"}

  def message(id, session, owner, text, interactions) do
    cond do
      not Enum.all?(interactions, &(&1 in ["clicked", "shared_data", "paid"])) ||
          length(Enum.uniq(interactions)) != length(interactions) ->
        {:error, 400, "invalid_followup"}

      true ->
        with {:ok, item} <- get(id, session, owner) do
          reserved =
            Repo.transaction(fn ->
              unless quota(session, owner, "followup", if(owner, do: 50, else: 10)),
                do: Repo.rollback(:quota)

              now = DateTime.utc_now()

              query =
                from c in Case,
                  where: c.id == ^item.id and c.turns < 5 and c.expires_at > ^now,
                  select: c.turns

              {count, turns} =
                Repo.update_all(query,
                  inc: [turns: 1],
                  set: [expires_at: min_date(DateTime.add(now, 3600), item.max_expires_at)]
                )

              if count != 1, do: Repo.rollback(:turn_limit)
              hd(turns)
            end)

          case reserved do
            {:ok, turns} ->
              reply =
                EverydayTrust.Interpreter.followup(item.result, text, interactions)
                |> String.slice(0, 700)

              {:ok, %{reply: reply, remaining_turns: max(0, 5 - turns)}}

            _ ->
              {:error, 429, "turn_limit"}
          end
        end
    end
  end

  def cleanup do
    EverydayTrust.Community.cleanup()
    now = DateTime.utc_now()

    Repo.all(from c in Case, where: c.analysis_pending and c.analysis_deadline < ^now)
    |> Enum.each(&expire_pending/1)

    Repo.delete_all(from c in Case, where: c.expires_at < ^now)
    Repo.query!("DELETE FROM quota_buckets WHERE expires_at < $1", [now])
    Repo.query!("DELETE FROM reviews WHERE inserted_at < $1", [DateTime.add(now, -30 * 86_400)])

    Repo.query!("DELETE FROM identity_deletions WHERE status='completed' AND expires_at < $1", [
      now
    ])
  end

  defp min_date(a, b), do: if(DateTime.compare(a, b) == :lt, do: a, else: b)

  defp encode_cursor(c),
    do: Base.url_encode64(DateTime.to_iso8601(c.inserted_at) <> "|" <> c.id, padding: false)

  defp decode_cursor(value) when is_binary(value) do
    with {:ok, s} <- Base.url_decode64(value, padding: false),
         [date, id] <- String.split(s, "|"),
         {:ok, date, _} <- DateTime.from_iso8601(date),
         {:ok, id} <- Ecto.UUID.cast(id),
         do: {:ok, date, id},
         else: (_ -> :error)
  end

  defp decode_cursor(_), do: :error
end
