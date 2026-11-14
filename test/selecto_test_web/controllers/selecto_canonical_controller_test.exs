defmodule SelectoTestWeb.SelectoCanonicalControllerTest do
  use SelectoTestWeb.ConnCase

  alias SelectoTest.PagilaData

  @base "/api/selecto/canonical"

  setup_all do
    PagilaData.ensure_loaded!()
    :ok
  end

  defp get_json(conn, path) do
    conn = get(conn, path)
    {conn.status, Jason.decode!(conn.resp_body)}
  end

  defp post_json(conn, path, body) do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(path, Jason.encode!(body))

    {conn.status, Jason.decode!(conn.resp_body)}
  end

  test "the catalog lists both Explorer domains with their manifests and metadata", %{conn: conn} do
    {200, catalog} = get_json(conn, @base <> "/catalog")
    assert catalog["format"] == "selecto.domain-catalog"

    assert Enum.map(catalog["domains"], &{&1["id"], &1["manifest"], &1["explorer_metadata"]}) == [
             {"actors", @base <> "/actors", @base <> "/actors/explorer"},
             {"films", @base <> "/films", @base <> "/films/explorer"}
           ]
  end

  test "each manifest advertises remote_query.v1 and remote_query.explorer.v1", %{conn: conn} do
    for id <- ~w(actors films) do
      {200, manifest} = get_json(conn, "#{@base}/#{id}")
      assert "remote_query.v1" in manifest["profiles"]
      assert "remote_query.explorer.v1" in manifest["profiles"]

      {200, metadata} = get_json(conn, "#{@base}/#{id}/explorer")
      assert metadata["format"] == "selecto.explorer-metadata"
      assert metadata["domain"]["fingerprint"] == manifest["domain"]["fingerprint"]

      {200, features} = get_json(conn, "#{@base}/#{id}/explorer-features")
      assert features["format"] == "selecto.explorer-features"
      assert features["domain"]["publication"] == metadata["domain"]["publication"]
    end

    {200, films} = get_json(conn, @base <> "/films/explorer")
    paths = Enum.map(films["fields"], & &1["path"])
    assert "title" in paths
    # The Pagila films domain marks description unfilterable, so it is not offered.
    refute "description" in paths
  end

  test "remote_query.v1 returns the same actor rows as SQL", %{conn: conn} do
    {200, manifest} = get_json(conn, @base <> "/actors")

    {200, response} =
      post_json(conn, @base <> "/actors/query", %{
        "format" => "selecto.remote-query",
        "format_version" => 1,
        "domain" => %{"fingerprint" => manifest["domain"]["fingerprint"]},
        "query" => %{
          "select" => ["actor_id", "first_name", "last_name"],
          "order_by" => [%{"field" => "actor_id", "direction" => "asc"}],
          "limit" => 5
        }
      })

    assert response["ok"] == true

    expected =
      PagilaData.rows!(
        "select actor_id, first_name, last_name from actor order by actor_id limit 5"
      )

    assert Enum.map(response["data"]["rows"], fn row -> Enum.map(row, &normalize/1) end) ==
             expected
  end

  test "remote_query.explorer.v1 groups films by rating", %{conn: conn} do
    {200, manifest} = get_json(conn, @base <> "/films")
    {200, features} = get_json(conn, @base <> "/films/explorer-features")

    {200, response} =
      post_json(conn, @base <> "/films/explorer-query", %{
        "format" => "selecto.explorer-query",
        "format_version" => 1,
        "domain" => %{"fingerprint" => manifest["domain"]["fingerprint"]},
        "features" => %{"revision" => features["revision"]},
        "request_id" => "ratings",
        "query" => %{
          "select" => ["rating", %{"aggregate" => "count", "field" => "film_id", "alias" => "n"}],
          "group_by" => ["rating"],
          "order_by" => [%{"field" => "rating", "direction" => "asc"}]
        }
      })

    expected =
      PagilaData.rows!("select rating::text, count(film_id) from film group by 1 order by 1")

    assert Enum.map(response["data"]["rows"], fn row -> Enum.map(row, &normalize/1) end) ==
             expected
  end

  test "refusals keep the canonical error envelope", %{conn: conn} do
    {200, manifest} = get_json(conn, @base <> "/actors")

    envelope = fn query, fingerprint ->
      %{
        "format" => "selecto.remote-query",
        "format_version" => 1,
        "domain" => %{"fingerprint" => fingerprint},
        "query" => query
      }
    end

    fingerprint = manifest["domain"]["fingerprint"]

    {422, unknown} =
      post_json(
        conn,
        @base <> "/actors/query",
        envelope.(%{"select" => ["password"]}, fingerprint)
      )

    assert unknown["ok"] == false

    {409, stale} =
      post_json(
        conn,
        @base <> "/actors/query",
        envelope.(%{"select" => ["actor_id"]}, "sha256:" <> String.duplicate("0", 64))
      )

    assert stale["ok"] == false

    {404, missing} = get_json(conn, @base <> "/rentals")
    assert missing["error"]["code"] == "route_not_found"
  end

  defp normalize(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> value
    end
  end

  defp normalize(value), do: value
end
