defmodule EverydayTrustWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :everyday_trust
  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: 32_768,
    read_length: 32_768,
    read_timeout: 5_000

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
