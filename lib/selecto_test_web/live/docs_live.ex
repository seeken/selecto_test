defmodule SelectoTestWeb.DocsLive do
  use SelectoTestWeb, :live_view

  def mount(%{"path" => path}, _session, socket) do
    doc_path = Path.join(["docs/selecto-system", path])

    case read_documentation(doc_path) do
      {:ok, content, title} ->
        socket =
          socket
          |> assign(content: content)
          |> assign(title: title)
          |> assign(path: path)
          |> assign(error: nil)

        {:ok, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(content: nil)
          |> assign(title: "Documentation Not Found")
          |> assign(path: path)
          |> assign(error: reason)

        {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-6">
          <h1 class="text-2xl font-bold text-red-800 mb-2">Documentation Not Found</h1>
          <p class="text-red-700">
            Could not load documentation for:
            <code class="bg-red-100 px-2 py-1 rounded">{@path}</code>
          </p>
          <p class="text-red-600 mt-2">Error: {@error}</p>

          <div class="mt-4">
            <.link
              navigate="/docs/selecto-system/system-overview"
              class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              📚 Go to System Overview
            </.link>
          </div>
        </div>
      <% else %>
        <!-- Documentation Navigation -->
        <div class="bg-white border border-gray-200 rounded-lg mb-6 p-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-4">
              <.link
                navigate="/docs/selecto-system/system-overview"
                class="text-blue-600 hover:text-blue-800 font-medium"
              >
                🏠 System Overview
              </.link>
            </div>

            <div class="flex items-center gap-2 text-sm text-gray-500">
              <span>📄 Current:</span>
              <code class="bg-gray-100 px-2 py-1 rounded text-xs">{@path}</code>
            </div>
          </div>
        </div>
        
    <!-- Documentation Content -->
        <div class="bg-white border border-gray-200 rounded-lg p-8">
          <div class="documentation-content">
            {raw(markdown_to_html(@content))}
          </div>
        </div>

        <style>
          .documentation-content h1 {
            font-size: 2.25rem;
            font-weight: 700;
            color: #111827;
            margin-top: 0;
            margin-bottom: 1.5rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid #e5e7eb;
          }

          .documentation-content h2 {
            font-size: 1.875rem;
            font-weight: 600;
            color: #111827;
            margin-top: 2rem;
            margin-bottom: 1rem;
          }

          .documentation-content h3 {
            font-size: 1.5rem;
            font-weight: 600;
            color: #111827;
            margin-top: 1.5rem;
            margin-bottom: 0.75rem;
          }

          .documentation-content h4 {
            font-size: 1.25rem;
            font-weight: 600;
            color: #111827;
            margin-top: 1rem;
            margin-bottom: 0.5rem;
          }

          .documentation-content p {
            color: #374151;
            line-height: 1.7;
            margin-bottom: 1rem;
          }

          .documentation-content a {
            color: #2563eb;
            text-decoration: underline;
            transition: color 0.2s;
          }

          .documentation-content a:hover {
            color: #1d4ed8;
          }

          .documentation-content strong {
            font-weight: 600;
            color: #111827;
          }

          .documentation-content em {
            font-style: italic;
            color: #374151;
          }

          .documentation-content code {
            background-color: #f3f4f6;
            color: #111827;
            padding: 0.125rem 0.375rem;
            border-radius: 0.25rem;
            font-family: ui-monospace, SFMono-Regular, "SF Mono", Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 0.875rem;
            border: 1px solid #d1d5db;
          }

          .documentation-content pre {
            background-color: #1f2937;
            color: #f9fafb;
            padding: 1rem;
            border-radius: 0.5rem;
            overflow-x: auto;
            margin: 1rem 0;
            border: 1px solid #374151;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
          }

          .documentation-content pre code {
            background: transparent;
            color: #f9fafb;
            padding: 0;
            border: none;
            font-size: 0.875rem;
          }

          .documentation-content ul, .documentation-content ol {
            padding-left: 1.5rem;
            margin-bottom: 1rem;
          }

          .documentation-content ul {
            list-style-type: disc;
          }

          .documentation-content ol {
            list-style-type: decimal;
          }

          .documentation-content li {
            color: #374151;
            margin-bottom: 0.25rem;
            line-height: 1.6;
          }

          .documentation-content table {
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
            border: 1px solid #d1d5db;
            border-radius: 0.5rem;
            overflow: hidden;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
          }

          .documentation-content thead {
            background-color: #f9fafb;
          }

          .documentation-content th {
            padding: 0.75rem 1rem;
            text-align: left;
            font-weight: 600;
            color: #111827;
            border-bottom: 1px solid #d1d5db;
          }

          .documentation-content td {
            padding: 0.75rem 1rem;
            color: #374151;
            border-bottom: 1px solid #e5e7eb;
          }

          .documentation-content tr:hover {
            background-color: #f9fafb;
          }

          .documentation-content blockquote {
            border-left: 4px solid #3b82f6;
            padding-left: 1rem;
            margin: 1rem 0;
            font-style: italic;
            color: #6b7280;
            background-color: #f8fafc;
            padding: 1rem;
            border-radius: 0.25rem;
          }

          .documentation-content blockquote p {
            margin: 0;
          }

          /* Warning/Alert styling */
          .documentation-content blockquote:has(strong:contains("⚠️")) {
            border-left-color: #f59e0b;
            background-color: #fffbeb;
            color: #92400e;
          }
        </style>
        
    <!-- Additional Resources -->
        <div class="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-blue-900 mb-3">💡 Additional Resources</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <.link
              navigate="/docs/selecto-system/index"
              class="block p-4 bg-white rounded-lg border border-blue-200 hover:border-blue-300 transition-colors"
            >
              <div class="text-blue-600 font-medium">🔍 API Reference</div>
              <div class="text-sm text-gray-600">Complete function documentation</div>
            </.link>

            <.link
              href="/pagila"
              class="block p-4 bg-white rounded-lg border border-blue-200 hover:border-blue-300 transition-colors"
            >
              <div class="text-green-600 font-medium">🎯 Live Demo</div>
              <div class="text-sm text-gray-600">Interactive Selecto demonstration</div>
            </.link>

            <.link
              href="https://github.com/selecto-elixir/selecto_test"
              class="block p-4 bg-white rounded-lg border border-blue-200 hover:border-blue-300 transition-colors"
            >
              <div class="text-gray-600 font-medium">🔗 Source Code</div>
              <div class="text-sm text-gray-600">View on GitHub</div>
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp read_documentation(doc_path) do
    # Use project root instead of compiled app directory
    project_root = File.cwd!()
    full_path = Path.join([project_root, doc_path])

    # Try with .md extension if not already present
    file_path =
      if String.ends_with?(full_path, ".md") do
        full_path
      else
        full_path <> ".md"
      end

    case File.read(file_path) do
      {:ok, content} ->
        title = extract_title(content)
        {:ok, content, title}

      {:error, :enoent} ->
        {:error, "File not found: #{file_path}"}

      {:error, reason} ->
        {:error, "Could not read file: #{inspect(reason)}"}
    end
  end

  defp extract_title(content) do
    case Regex.run(~r/^#\s+(.+)$/m, content) do
      [_, title] -> String.trim(title)
      _ -> "Documentation"
    end
  end

  defp markdown_to_html(content) do
    case Earmark.as_html(content, earmark_options()) do
      {:ok, html, []} ->
        html

      {:ok, html, warnings} ->
        # Log warnings but still return the HTML
        Enum.each(warnings, &IO.warn("Markdown warning: #{inspect(&1)}"))
        html

      {:error, html, errors} ->
        # Log errors but return what HTML we could generate
        Enum.each(errors, &IO.warn("Markdown error: #{inspect(&1)}"))
        html
    end
  end

  defp earmark_options do
    %Earmark.Options{
      # Enable GitHub Flavored Markdown features
      gfm: true,
      # Enable tables
      gfm_tables: true,
      # Enable strikethrough
      breaks: false,
      # Add classes for syntax highlighting (works with Prism.js or similar)
      code_class_prefix: "language-",
      # Disable unsafe HTML for security
      pure_links: true,
      # Enable footnotes
      footnotes: true,
      # Enable definition lists  
      pedantic: false,
      # Enable smartypants for smart quotes
      smartypants: true
    }
  end
end
