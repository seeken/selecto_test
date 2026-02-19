defmodule SelectoTest.Overlays.PagilaDomainFilmsOverlay do
  @moduledoc """
  Overlay configuration for the Pagila Films domain.

  This overlay customizes column display formats, labels, and filter
  configurations specific to the film-centric domain view.
  """
  use Selecto.Config.OverlayDSL

  # Primary film columns
  defcolumn :film_id do
    label("Film ID")
    sortable(true)
    filterable(true)
  end

  defcolumn :title do
    label("Title")
    sortable(true)
    filterable(true)
    max_length(255)
  end

  defcolumn :description do
    label("Description")
    max_length(500)
    sortable(false)
  end

  defcolumn :release_year do
    label("Release Year")
    sortable(true)
    filterable(true)
    aggregate_functions([:min, :max, :count])
  end

  defcolumn :rental_duration do
    label("Rental Duration (days)")
    format(:number)
    aggregate_functions([:avg, :min, :max])
  end

  defcolumn :rental_rate do
    label("Rental Rate")
    format(:currency)
    precision(2)
    aggregate_functions([:sum, :avg, :min, :max])
  end

  defcolumn :length do
    label("Length (minutes)")
    format(:number)
    aggregate_functions([:avg, :min, :max, :sum])
  end

  defcolumn :replacement_cost do
    label("Replacement Cost")
    format(:currency)
    precision(2)
    aggregate_functions([:sum, :avg, :min, :max])
  end

  defcolumn :rating do
    label("MPAA Rating")
    sortable(true)
    filterable(true)
  end

  defcolumn :special_features do
    label("Special Features")
    filterable(true)
  end

  # Actor columns (for joined actor data)
  defcolumn :first_name do
    label("Actor First Name")
    sortable(true)
    filterable(true)
  end

  defcolumn :last_name do
    label("Actor Last Name")
    sortable(true)
    filterable(true)
  end

  # Language column
  defcolumn :name do
    label("Language")
    sortable(true)
    filterable(true)
  end

  # Custom filters for film domain
  deffilter "title_search" do
    name("Title Search")
    type(:string)
    description("Search films by title")
  end

  deffilter "release_year_range" do
    name("Release Year Range")
    type(:integer)
    description("Filter films by release year range")
  end

  deffilter "rental_rate_range" do
    name("Rental Rate Range")
    type(:decimal)
    description("Filter films by rental rate")
  end

  deffilter "length_range" do
    name("Length Range")
    type(:integer)
    description("Filter films by length in minutes")
  end

  deffilter "has_special_feature" do
    name("Has Special Feature")
    type(:string)
    description("Filter films that have a specific special feature")
    options(["Trailers", "Commentaries", "Deleted Scenes", "Behind the Scenes"])
  end
end
