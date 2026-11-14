defmodule SelectoTestWeb.SelectoCanonicalController do
  @moduledoc """
  Copies requests under `/api/selecto/canonical` to `SelectoTest.CanonicalApi`
  and its status, headers and body back to the response.
  """

  use SelectoTestWeb, :controller

  alias SelectoTest.CanonicalApi

  def dispatch(conn, _params) do
    body = if conn.method == "POST", do: json_body(conn.body_params)
    headers = Map.new(conn.req_headers)
    response = CanonicalApi.request(conn.method, conn.request_path, body, headers)

    response.headers
    |> Enum.reduce(conn, fn {name, value}, conn -> put_resp_header(conn, name, value) end)
    |> put_resp_header("cache-control", "no-store, private")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> send_resp(response.status, response.body)
  end

  # Plug.Parsers wraps a JSON body that is not an object in "_json".
  defp json_body(%{"_json" => value} = params) when map_size(params) == 1, do: value
  defp json_body(%Plug.Conn.Unfetched{}), do: nil
  defp json_body(params), do: params
end
