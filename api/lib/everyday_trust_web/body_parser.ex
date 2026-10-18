defmodule EverydayTrustWeb.BodyParser do
  @behaviour Plug

  @normal_limit 32_768
  @image_limit 3_145_728

  @impl true
  def init(options), do: options

  @impl true
  def call(conn, _) do
    limit =
      if conn.method == "POST" and conn.path_info == ["api", "v1", "image-cases"] and
           EverydayTrust.ImageInput.enabled?(),
         do: @image_limit,
         else: @normal_limit

    Plug.Parsers.call(
      conn,
      Plug.Parsers.init(
        parsers: [:json],
        pass: ["application/json"],
        json_decoder: Jason,
        length: limit,
        read_length: limit,
        read_timeout: 5_000
      )
    )
  end
end
