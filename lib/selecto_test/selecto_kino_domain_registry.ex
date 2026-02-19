defmodule SelectoKino.DomainRegistry do
  @moduledoc """
  Domain registry for SelectoKino integration.
  Provides access to available domains and their configurations.
  """

  alias SelectoTest.{PagilaDomain, PagilaDomainFilms}

  @doc """
  Lists all available domains for SelectoKino.
  """
  def list_domains() do
    %{
      "pagila_domain" => %{
        name: "Pagila Database",
        description: "Film rental database with actors, films, and categories"
      },
      "pagila_domain_films" => %{
        name: "Pagila Films",
        description: "Enhanced film domain with custom columns and filters"
      },
      "blog_domain" => %{
        name: "Blog System",
        description: "Blog posts with authors, categories, and comments"
      }
    }
  end

  @doc """
  Gets the domain configuration for a specific domain.
  """
  def get_domain(domain_name) do
    case domain_name do
      "pagila_domain" ->
        PagilaDomain.actors_domain()

      "pagila_domain_films" ->
        PagilaDomainFilms.domain()

      "blog_domain" ->
        # For now, return a simplified domain config since BlogDomain doesn't exist
        %{
          name: "Blog System",
          description: "Blog posts with authors, categories, and comments",
          source: %{
            source_table: "author",
            columns: %{
              id: %{type: :integer, name: "ID"},
              name: %{type: :string, name: "Name"},
              email: %{type: :string, name: "Email"},
              bio: %{type: :string, name: "Biography"}
            }
          }
        }

      _ ->
        {:error, "Unknown domain: #{domain_name}. Available domains: #{available_domain_names()}"}
    end
  end

  defp available_domain_names() do
    list_domains()
    |> Map.keys()
    |> Enum.join(", ")
  end
end
