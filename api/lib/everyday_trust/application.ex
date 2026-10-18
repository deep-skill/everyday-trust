defmodule EverydayTrust.Application do
  use Application

  def start(_type, _args) do
    children = [
      EverydayTrust.Repo,
      {Task.Supervisor, name: EverydayTrust.AnalysisTasks, max_children: 20},
      EverydayTrust.SafeBrowsing,
      EverydayTrust.SourceDisplay,
      EverydayTrust.Urlscan.Cache,
      {Phoenix.PubSub, name: EverydayTrust.PubSub},
      EverydayTrust.Identity.Keys,
      EverydayTrust.Cleanup,
      EverydayTrustWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EverydayTrust.Supervisor)
  end
end
