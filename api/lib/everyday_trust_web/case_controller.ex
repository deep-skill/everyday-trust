defmodule EverydayTrustWeb.CaseController do
  use Phoenix.Controller, formats: [:json]
  alias EverydayTrust.Cases

  def delete_account(conn, _) do
    if conn.assigns[:identity],
      do: respond(conn, EverydayTrust.Accounts.delete(conn.assigns.identity)),
      else: respond(conn, {:error, 401, "unauthorized"})
  end

  def stats(conn, _), do: json(conn, EverydayTrust.Metrics.today())

  def visit(conn, _),
    do: json(conn, EverydayTrust.Metrics.visit(conn.assigns.session, conn.assigns.network))

  def review(conn, %{"id" => id} = params) do
    respond(
      conn,
      EverydayTrust.Reviews.submit(
        id,
        conn.assigns.session,
        conn.assigns.owner,
        conn.assigns.network,
        params["rating"],
        Map.get(params, "comment", "")
      )
    )
  end

  def delete_review(conn, %{"id" => id}),
    do: respond(conn, EverydayTrust.Reviews.delete(id, conn.assigns.session, conn.assigns.owner))

  def health(conn, _), do: json(conn, %{status: "ok", version: "0.1.0"})

  def create(conn, %{"text" => text}) when is_binary(text) do
    cond do
      String.trim(text) == "" ->
        respond(conn, {:error, 400, "empty_message"})

      String.length(text) > 5_000 ->
        respond(conn, {:error, 413, "message_too_long"})

      true ->
        respond(
          conn,
          Cases.create(text, conn.assigns.session, conn.assigns.owner,
            network: conn.assigns.network,
            demo: conn.params["demo"] == true
          ),
          201
        )
    end
  end

  def create(conn, _), do: respond(conn, {:error, 400, "invalid_message"})

  def show(conn, %{"id" => id}) do
    case Cases.get(id, conn.assigns.session, conn.assigns.owner) do
      {:ok, item} -> json(conn, Cases.present(item))
      error -> respond(conn, error)
    end
  end

  def save(conn, %{"id" => id}),
    do: with_owner(conn, fn owner -> Cases.save(id, conn.assigns.session, owner) end)

  def history(conn, params),
    do: with_owner(conn, fn owner -> {:ok, Cases.history(owner, params["cursor"])} end)

  def saved(conn, %{"id" => id}) do
    with_owner(conn, fn owner ->
      with {:ok, item} <- Cases.saved(id, owner),
           do: {:ok, %{id: item.id, result: item.result, created_at: item.inserted_at}}
    end)
  end

  def delete(conn, %{"id" => id}), do: with_owner(conn, fn owner -> Cases.delete(id, owner) end)

  def feedback(conn, %{"id" => id, "value" => value}),
    do: respond(conn, Cases.feedback(id, conn.assigns.session, conn.assigns.owner, value))

  def feedback(conn, _), do: respond(conn, {:error, 400, "invalid_feedback"})

  def message(conn, %{"id" => id} = params) do
    text = Map.get(params, "text", "")
    interactions = Map.get(params, "interactions", [])

    if is_binary(text) && String.length(text) <= 1_000 && is_list(interactions) &&
         length(interactions) <= 3 && (String.trim(text) != "" || interactions != []) do
      respond(
        conn,
        Cases.message(id, conn.assigns.session, conn.assigns.owner, text, interactions)
      )
    else
      respond(conn, {:error, 400, "invalid_followup"})
    end
  end

  def me(conn, _),
    do:
      with_owner(conn, fn _ ->
        {:ok,
         %{
           authenticated: true,
           benefits: %{daily_queries: 25, history: true},
           max_turns_per_case: 5
         }}
      end)

  defp with_owner(conn, fun),
    do:
      if(conn.assigns.owner,
        do: respond(conn, fun.(conn.assigns.owner)),
        else: respond(conn, {:error, 401, "unauthorized"})
      )

  defp respond(conn, {:ok, value}, status), do: conn |> put_status(status) |> json(value)

  defp respond(conn, {:error, status, code}, _) do
    if conn.request_path == "/api/v1/cases", do: EverydayTrust.Metrics.error()
    conn = if status == 429, do: put_resp_header(conn, "retry-after", "3600"), else: conn

    conn
    |> put_status(status)
    |> json(%{
      error: %{
        code: code,
        message: message_for_code(code, status),
        request_id: get_resp_header(conn, "x-request-id") |> List.first()
      }
    })
  end

  defp respond(conn, result), do: respond(conn, result, 200)

  defp message_for_code("recent_login_required", _),
    do:
      "Vuelve a identificarte desde Cuenta antes de eliminarla. Se requiere un acceso de los últimos cinco minutos."

  defp message_for_code("identity_deletion_pending", _),
    do:
      "Tus consultas ya se eliminaron. La eliminación en el proveedor de identidad está pendiente; vuelve a intentarlo desde Cuenta."

  defp message_for_code("review_limit", _),
    do: "Por hoy ya enviaste tus valoraciones. Gracias por ayudarnos a mejorar."

  defp message_for_code("invalid_review", _),
    do: "Elige de una a cinco estrellas y un comentario de hasta 500 caracteres."

  defp message_for_code(_, status), do: message_for(status)
  defp message_for(401), do: "Inicia sesión para continuar."
  defp message_for(404), do: "La consulta no existe o ya venció."
  defp message_for(429), do: "Llegaste al límite de consultas. Inténtalo más tarde."

  defp message_for(_),
    do: "No pudimos completar esta solicitud. Revisa los datos e inténtalo otra vez."
end
