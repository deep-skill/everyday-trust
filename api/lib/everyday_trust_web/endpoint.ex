defmodule EverydayTrustWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :everyday_trust
  plug Plug.RequestId

  plug EverydayTrustWeb.BodyParser

  plug EverydayTrustWeb.Router
end

defmodule EverydayTrustWeb.ErrorJSON do
  def render(template, _),
    do: %{
      error: %{
        code: "request_failed",
        message: Phoenix.Controller.status_message_from_template(template)
      }
    }
end
