defmodule SelectoTest.Overlays.PagilaDomainOverlay do
  @moduledoc """
  Overlay configuration for the Pagila Actor domain.

  This overlay customizes column display formats, labels, and adds
  metadata for the actor domain and its related film schema.
  """
  use Selecto.Config.OverlayDSL

  # Actor columns
  defcolumn :actor_id do
    label("Actor ID")
    sortable(true)
    filterable(true)
  end

  defcolumn :first_name do
    label("First Name")
    sortable(true)
    filterable(true)
    max_length(50)
  end

  defcolumn :last_name do
    label("Last Name")
    sortable(true)
    filterable(true)
    max_length(50)
  end

  # Film columns (for joined film data)
  defcolumn :rental_rate do
    label("Rental Rate")
    format(:currency)
    precision(2)
    aggregate_functions([:sum, :avg, :min, :max])
  end

  defcolumn :replacement_cost do
    label("Replacement Cost")
    format(:currency)
    precision(2)
    aggregate_functions([:sum, :avg, :min, :max])
  end

  defcolumn :rental_duration do
    label("Rental Duration")
    format(:number)
    aggregate_functions([:avg, :min, :max])
  end

  defcolumn :length do
    label("Film Length (min)")
    format(:number)
    aggregate_functions([:avg, :min, :max])
  end

  defcolumn :release_year do
    label("Release Year")
    sortable(true)
    filterable(true)
  end

  defcolumn :rating do
    label("Rating")
    sortable(true)
    filterable(true)
  end

  defcolumn :special_features do
    label("Special Features")
    filterable(true)
  end

  # Custom filters via overlay
  deffilter "actor_name_search" do
    name("Actor Name Search")
    type(:string)
    description("Search actors by first or last name")
  end

  deffilter "film_count_range" do
    name("Film Count Range")
    type(:integer)
    description("Filter actors by number of films")
  end
end
