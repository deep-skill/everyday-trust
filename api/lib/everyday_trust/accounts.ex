defmodule EverydayTrust.Accounts do
  import Ecto.Query
  alias EverydayTrust.{Repo, Profile}

  defp key(identity),
    do:
      :crypto.hash(:sha256, identity.issuer <> "|" <> identity.subject)
      |> Base.encode16(case: :lower)

  def blocked?(identity),
    do:
      Repo.query!("SELECT 1 FROM identity_deletions WHERE identity_hash=$1", [key(identity)]).num_rows >
        0

  def delete(identity) do
    now = System.system_time(:second)

    if is_integer(identity.auth_time) && identity.auth_time <= now + 30 &&
         now - identity.auth_time <= 300 do
      Repo.transaction(fn ->
        Repo.query!(
          "INSERT INTO identity_deletions (identity_hash,status,expires_at) VALUES ($1,'pending',$2) ON CONFLICT DO NOTHING",
          [key(identity), DateTime.add(DateTime.utc_now(), 86_400)]
        )

        Repo.delete_all(
          from p in Profile,
            where: p.issuer == ^identity.issuer and p.subject == ^identity.subject
        )
      end)

      case remote_delete(identity) do
        :ok ->
          Repo.query!("UPDATE identity_deletions SET status='completed' WHERE identity_hash=$1", [
            key(identity)
          ])

          {:ok, %{deleted: true}}

        _ ->
          {:error, 503, "identity_deletion_pending"}
      end
    else
      {:error, 403, "recent_login_required"}
    end
  end

  defp remote_delete(identity) do
    case Application.get_env(:everyday_trust, :test_identity_delete) do
      fun when is_function(fun, 1) ->
        fun.(identity)

      _ ->
        uri = URI.parse(identity.issuer)

        case Req.post("https://" <> uri.host,
               json: %{"AccessToken" => identity.token},
               headers: [
                 {"content-type", "application/x-amz-json-1.1"},
                 {"x-amz-target", "AWSCognitoIdentityProviderService.DeleteUser"}
               ],
               redirect: false,
               retry: false,
               receive_timeout: 3_000,
               connect_options: [timeout: 1_000]
             ) do
          {:ok, %{status: 200}} -> :ok
          _ -> :error
        end
    end
  rescue
    _ -> :error
  end
end
