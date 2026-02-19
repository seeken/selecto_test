defmodule SelectoTestWeb.LiveDashboard.SelectoPage do
  @moduledoc """
  LiveDashboard page for Selecto query metrics and performance monitoring.
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Selecto"}
  end

  @impl true
  def init(_) do
    {:ok, %{}, []}
  end

  @impl true
  def render(assigns) do
    metrics_data = get_metrics_data()
    slow_queries = get_slow_queries()
    cache_stats = get_cache_stats()

    assigns =
      Map.merge(assigns, %{
        metrics: metrics_data.metrics,
        percentiles: metrics_data.percentiles,
        slow_queries: slow_queries,
        cache_stats: cache_stats
      })

    ~H"""
    <div class="row">
      <div class="col-sm-6">
        <.card title="Query Performance">
          <table class="table table-sm">
            <tbody>
              <tr>
                <td>Total Queries</td>
                <td class="text-right">{@metrics.total_queries}</td>
              </tr>
              <tr>
                <td>Avg Response Time</td>
                <td class="text-right">{@metrics.avg_response_time}ms</td>
              </tr>
              <tr>
                <td>Queries Per Minute</td>
                <td class="text-right">{@metrics.queries_per_minute}</td>
              </tr>
              <tr>
                <td>Error Rate</td>
                <td class={"text-right #{error_class(@metrics.error_rate)}"}>
                  {@metrics.error_rate}%
                </td>
              </tr>
              <tr>
                <td>Slow Queries (>500ms)</td>
                <td class="text-right">{@metrics.slow_query_count}</td>
              </tr>
            </tbody>
          </table>
        </.card>
      </div>

      <div class="col-sm-6">
        <.card title="Response Time Percentiles">
          <table class="table table-sm">
            <tbody>
              <tr>
                <td>P50 (Median)</td>
                <td class="text-right">{@percentiles.p50}ms</td>
              </tr>
              <tr>
                <td>P95</td>
                <td class="text-right">{@percentiles.p95}ms</td>
              </tr>
              <tr>
                <td>P99</td>
                <td class="text-right">{@percentiles.p99}ms</td>
              </tr>
            </tbody>
          </table>
        </.card>
      </div>
    </div>

    <div class="row">
      <div class="col-sm-6">
        <.card title="Cache Statistics">
          <table class="table table-sm">
            <tbody>
              <tr>
                <td>Hit Rate</td>
                <td class={"text-right #{cache_class(@cache_stats.hit_rate)}"}>
                  {@cache_stats.hit_rate}%
                </td>
              </tr>
              <tr>
                <td>Total Hits</td>
                <td class="text-right">{@cache_stats.hits}</td>
              </tr>
              <tr>
                <td>Total Misses</td>
                <td class="text-right">{@cache_stats.misses}</td>
              </tr>
            </tbody>
          </table>
        </.card>
      </div>

      <div class="col-sm-6">
        <.card title="Index Usage">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Most Used Indexes</th>
                <th class="text-right">Uses</th>
              </tr>
            </thead>
            <tbody>
              <%= for index <- get_most_used_indexes() do %>
                <tr>
                  <td>{index.name}</td>
                  <td class="text-right">{index.usage_count}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </.card>
      </div>
    </div>

    <div class="row">
      <div class="col-sm-12">
        <.card title="Slow Queries (>500ms)">
          <%= if @slow_queries == [] do %>
            <div class="text-center text-muted py-4">
              <p>🎉 No slow queries detected</p>
            </div>
          <% else %>
            <div class="table-responsive">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Duration</th>
                    <th>Query</th>
                    <th>Rows</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for query <- Enum.take(@slow_queries, 10) do %>
                    <tr>
                      <td class="text-nowrap">{format_timestamp(query[:timestamp])}</td>
                      <td class="text-nowrap">
                        <span class="badge badge-danger">{query[:execution_time]}ms</span>
                      </td>
                      <td class="text-break">
                        <code class="small">{format_sql(query[:query])}</code>
                      </td>
                      <td class="text-right">{query[:row_count] || 0}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </.card>
      </div>
    </div>
    """
  end

  # Data fetching functions

  defp get_metrics_data do
    if Process.whereis(SelectoComponents.Performance.MetricsCollector) do
      metrics = SelectoComponents.Performance.MetricsCollector.get_metrics("1h")

      %{
        metrics: metrics,
        percentiles: metrics[:percentiles] || %{p50: 0, p95: 0, p99: 0}
      }
    else
      %{
        metrics: %{
          total_queries: 0,
          avg_response_time: 0,
          error_rate: 0.0,
          queries_per_minute: 0,
          error_count: 0,
          slow_query_count: 0
        },
        percentiles: %{p50: 0, p95: 0, p99: 0}
      }
    end
  end

  defp get_slow_queries do
    if Process.whereis(SelectoComponents.Performance.MetricsCollector) do
      SelectoComponents.Performance.MetricsCollector.get_slow_queries(500, 10)
    else
      []
    end
  end

  defp get_cache_stats do
    # For now, return mock data - in production, this would come from MetricsCollector
    %{
      hit_rate: 85,
      hits: 1523,
      misses: 267
    }
  end

  defp get_most_used_indexes do
    # Mock data - in production, query from database statistics
    [
      %{name: "idx_film_title", usage_count: 1523},
      %{name: "idx_customer_email", usage_count: 892},
      %{name: "idx_rental_date", usage_count: 654}
    ]
  end

  # Helper functions

  defp error_class(rate) when rate > 5, do: "text-danger"
  defp error_class(_), do: "text-success"

  defp cache_class(rate) when rate > 80, do: "text-success"
  defp cache_class(rate) when rate > 60, do: "text-warning"
  defp cache_class(_), do: "text-danger"

  defp format_timestamp(nil), do: "Unknown"

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp format_sql(nil), do: "No query available"

  defp format_sql(sql) when byte_size(sql) > 200 do
    String.slice(sql, 0, 200) <> "..."
  end

  defp format_sql(sql), do: sql
end
