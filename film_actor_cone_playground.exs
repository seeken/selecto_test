#!/usr/bin/env elixir

# FilmCone LiveView using Phoenix Playground
# Film & Actor Management with many-to-many relationships

Application.put_env(:phoenix_playground, :live_reload, true)

Mix.install([
  {:phoenix_playground, "~> 0.1.7"},
  {:ecto_sql, "~> 3.10"},
  {:postgrex, "~> 0.17"}
])

# Configure database
Application.put_env(:film_cone, FilmCone.Repo,
  database: System.get_env("DB_NAME", "selecto_test_dev"),
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  pool_size: 10
)

defmodule FilmCone.Repo do
  use Ecto.Repo,
    otp_app: :film_cone,
    adapter: Ecto.Adapters.Postgres
end

# Import schema modules
alias Elixir.SelectoTest.Store.Film
alias Elixir.SelectoTest.Store.Actor
alias Elixir.SelectoTest.Store.FilmActor

defmodule FilmCone.ConeLive do
  use Phoenix.LiveView
  use Phoenix.Component
  import Phoenix.HTML.Form
  import Ecto.Query
  
  def mount(_params, _session, socket) do
    films = list_films()
    
    socket =
      socket
      |> assign(:films, films)
      |> assign(:selected_film, nil)
      |> assign(:actors, [])
      |> assign(:form_mode, nil)
      |> assign(:changeset, nil)
      |> assign(:available_actors, [])
      |> assign(:selected_actor_ids, [])
      |> assign(:actor_search, "")
      |> assign(:new_actor_name, "")
      |> assign(:stats, calculate_stats(films))
    
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div style="font-family: system-ui, -apple-system, sans-serif; max-width: 1200px; margin: 0 auto; padding: 2rem;">
      <h1 style="font-size: 2rem; font-weight: bold; margin-bottom: 2rem;">
        🎬 FilmCone - Film & Actor Management
      </h1>
      
      <!-- Stats Dashboard -->
      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin-bottom: 2rem;">
        <div style="background: #EBF8FF; padding: 1rem; border-radius: 0.5rem;">
          <div style="color: #718096; font-size: 0.875rem;">Total Films</div>
          <div style="font-size: 1.5rem; font-weight: bold;"><%= @stats.total_films %></div>
        </div>
        <div style="background: #F0FDF4; padding: 1rem; border-radius: 0.5rem;">
          <div style="color: #718096; font-size: 0.875rem;">Total Actors</div>
          <div style="font-size: 1.5rem; font-weight: bold;"><%= @stats.total_actors %></div>
        </div>
        <div style="background: #FEF3C7; padding: 1rem; border-radius: 0.5rem;">
          <div style="color: #718096; font-size: 0.875rem;">Avg Actors/Film</div>
          <div style="font-size: 1.5rem; font-weight: bold;"><%= @stats.avg_actors_per_film %></div>
        </div>
      </div>
      
      <div style="display: grid; grid-template-columns: 1fr 2fr; gap: 1.5rem;">
        <!-- Films (Apex) -->
        <div style="background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <h2 style="font-size: 1.25rem; font-weight: 600;">Films</h2>
            <button 
              phx-click="new_film" 
              style="background: #3B82F6; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer;">
              + New Film
            </button>
          </div>
          
          <div style="max-height: 32rem; overflow-y: auto;">
            <%= for film <- @films do %>
              <div
                phx-click="select_film"
                phx-value-id={film.film_id}
                style={"padding: 0.75rem; margin-bottom: 0.5rem; border: 1px solid #E5E7EB; border-radius: 0.25rem; cursor: pointer; #{if @selected_film && @selected_film.film_id == film.film_id, do: "background: #DBEAFE; border-color: #3B82F6;", else: "background: white;"}"}
              >
                <div style="font-weight: 500;"><%= film.title %></div>
                <div style="font-size: 0.875rem; color: #6B7280;">
                  <%= film.release_year %> • <%= film.rating || "Not Rated" %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
        <!-- Actors (Associated) -->
        <div style="background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <h2 style="font-size: 1.25rem; font-weight: 600;">
              <%= if @selected_film do %>
                Actors in "<%= @selected_film.title %>"
              <% else %>
                Actors
              <% end %>
            </h2>
            <%= if @selected_film do %>
              <button 
                phx-click="manage_actors"
                style="background: #10B981; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer;">
                Manage Actors
              </button>
            <% end %>
          </div>
          
          <%= if @selected_film do %>
            <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.75rem;">
              <%= for actor <- @actors do %>
                <div style="padding: 0.75rem; border: 1px solid #E5E7EB; border-radius: 0.25rem; background: white; display: flex; justify-content: space-between; align-items: center;">
                  <div>
                    <div style="font-weight: 500;">
                      <%= actor.first_name %> <%= actor.last_name %>
                    </div>
                  </div>
                  <button 
                    phx-click="remove_actor"
                    phx-value-actor-id={actor.actor_id}
                    style="background: #EF4444; color: white; padding: 0.125rem 0.5rem; border-radius: 0.25rem; border: none; cursor: pointer; font-size: 0.875rem;">
                    Remove
                  </button>
                </div>
              <% end %>
            </div>
          <% else %>
            <div style="text-align: center; color: #9CA3AF; padding: 4rem 0;">
              Select a film to view its actors
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Form Modal -->
      <%= if @form_mode == :manage_actors do %>
        <div style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 50;">
          <div style="background: white; border-radius: 0.5rem; padding: 1.5rem; width: 36rem; max-height: 80vh; overflow-y: auto;">
            <h3 style="font-size: 1.125rem; font-weight: 600; margin-bottom: 1rem;">
              Manage Actors for "<%= @selected_film.title %>"
            </h3>
            
            <!-- Search existing actors -->
            <div style="margin-bottom: 1rem;">
              <label style="display: block; margin-bottom: 0.25rem; font-weight: 500;">Search Actors</label>
              <input 
                type="text"
                phx-keyup="search_actors"
                phx-debounce="300"
                value={@actor_search}
                placeholder="Type to search actors..."
                style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;">
            </div>
            
            <!-- Available actors list -->
            <div style="max-height: 12rem; overflow-y: auto; border: 1px solid #E5E7EB; border-radius: 0.25rem; padding: 0.5rem; margin-bottom: 1rem;">
              <%= for actor <- @available_actors do %>
                <label style="display: flex; align-items: center; padding: 0.25rem; cursor: pointer;">
                  <input 
                    type="checkbox"
                    phx-click="toggle_actor"
                    phx-value-actor-id={actor.actor_id}
                    checked={actor.actor_id in @selected_actor_ids}
                    style="margin-right: 0.5rem;">
                  <%= actor.first_name %> <%= actor.last_name %>
                </label>
              <% end %>
            </div>
            
            <!-- Create new actor -->
            <div style="border-top: 1px solid #E5E7EB; padding-top: 1rem; margin-bottom: 1rem;">
              <label style="display: block; margin-bottom: 0.25rem; font-weight: 500;">Or Create New Actor</label>
              <.form for={%{}} phx-submit="create_actor">
                <div style="display: flex; gap: 0.5rem;">
                  <input 
                    type="text"
                    name="first_name"
                    placeholder="First Name"
                    style="flex: 1; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;">
                  <input 
                    type="text"
                    name="last_name"
                    placeholder="Last Name"
                    style="flex: 1; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;">
                  <button 
                    type="submit"
                    style="background: #8B5CF6; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer; font-size: 0.875rem;">
                    Create & Add Actor
                  </button>
                </div>
              </.form>
            </div>
            
            <div style="display: flex; gap: 0.5rem; justify-content: flex-end; margin-top: 1rem;">
              <button 
                phx-click="cancel_form" 
                style="background: #9CA3AF; color: white; padding: 0.5rem 1rem; border-radius: 0.25rem; border: none; cursor: pointer;">
                Cancel
              </button>
              <button 
                phx-click="save_actors"
                style="background: #10B981; color: white; padding: 0.5rem 1rem; border-radius: 0.25rem; border: none; cursor: pointer;">
                Save Selected Actors (<%= length(@selected_actor_ids) %>)
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
      <%= if @form_mode == :new_film do %>
        <div style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 50;">
          <div style="background: white; border-radius: 0.5rem; padding: 1.5rem; width: 32rem;">
            <h3 style="font-size: 1.125rem; font-weight: 600; margin-bottom: 1rem;">
              Create New Film
            </h3>
            <.form for={%{}} phx-submit="create_film">
              <div style="margin-bottom: 1rem;">
                <label style="display: block; margin-bottom: 0.25rem; font-weight: 500;">Title</label>
                <input 
                  type="text"
                  name="title"
                  required
                  style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;">
              </div>
              
              <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; margin-bottom: 1rem;">
                <div>
                  <label style="display: block; margin-bottom: 0.25rem; font-weight: 500;">Release Year</label>
                  <input 
                    type="number"
                    name="release_year"
                    min="1900"
                    max="2030"
                    style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;">
                </div>
                <div>
                  <label style="display: block; margin-bottom: 0.25rem; font-weight: 500;">Rating</label>
                  <select 
                    name="rating"
                    style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;">
                    <option value="">Select Rating</option>
                    <option value="G">G</option>
                    <option value="PG">PG</option>
                    <option value="PG-13">PG-13</option>
                    <option value="R">R</option>
                    <option value="NC-17">NC-17</option>
                  </select>
                </div>
              </div>
              
              <div style="margin-bottom: 1rem;">
                <label style="display: block; margin-bottom: 0.25rem; font-weight: 500;">Description</label>
                <textarea 
                  name="description"
                  rows="3"
                  style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"></textarea>
              </div>
              
              <div style="display: flex; gap: 0.5rem; justify-content: flex-end;">
                <button 
                  type="button"
                  phx-click="cancel_form"
                  style="background: #9CA3AF; color: white; padding: 0.5rem 1rem; border-radius: 0.25rem; border: none; cursor: pointer;">
                  Cancel
                </button>
                <button 
                  type="submit"
                  style="background: #3B82F6; color: white; padding: 0.5rem 1rem; border-radius: 0.25rem; border: none; cursor: pointer;">
                  Create Film
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Event Handlers
  
  def handle_event("select_film", %{"id" => id}, socket) do
    film = FilmCone.Repo.get!(Film, id)
    actors = list_film_actors(film.film_id)
    
    socket =
      socket
      |> assign(:selected_film, film)
      |> assign(:actors, actors)
    
    {:noreply, socket}
  end
  
  def handle_event("new_film", _params, socket) do
    socket = assign(socket, :form_mode, :new_film)
    {:noreply, socket}
  end
  
  def handle_event("create_film", params, socket) do
    attrs = %{
      title: params["title"],
      description: params["description"],
      release_year: String.to_integer(params["release_year"] || "2024"),
      rating: params["rating"],
      rental_duration: 3,
      rental_rate: Decimal.new("4.99"),
      replacement_cost: Decimal.new("19.99"),
      language_id: 1
    }
    
    changeset = Film.changeset(%Film{}, attrs)
    
    case FilmCone.Repo.insert(changeset) do
      {:ok, film} ->
        films = list_films()
        
        socket =
          socket
          |> assign(:films, films)
          |> assign(:selected_film, film)
          |> assign(:actors, [])
          |> assign(:form_mode, nil)
          |> assign(:stats, calculate_stats(films))
          |> put_flash(:info, "Film created successfully!")
        
        {:noreply, socket}
        
      {:error, changeset} ->
        socket =
          socket
          |> assign(:changeset, changeset)
          |> put_flash(:error, "Failed to create film")
        
        {:noreply, socket}
    end
  end
  
  def handle_event("manage_actors", _params, socket) do
    all_actors = list_all_actors()
    current_actor_ids = Enum.map(socket.assigns.actors, & &1.actor_id)
    
    socket =
      socket
      |> assign(:form_mode, :manage_actors)
      |> assign(:available_actors, all_actors)
      |> assign(:selected_actor_ids, current_actor_ids)
      |> assign(:actor_search, "")
    
    {:noreply, socket}
  end
  
  def handle_event("search_actors", %{"value" => search}, socket) do
    actors = search_actors(search)
    
    socket =
      socket
      |> assign(:available_actors, actors)
      |> assign(:actor_search, search)
    
    {:noreply, socket}
  end
  
  def handle_event("toggle_actor", %{"actor-id" => actor_id}, socket) do
    actor_id = String.to_integer(actor_id)
    selected = socket.assigns.selected_actor_ids
    
    selected =
      if actor_id in selected do
        List.delete(selected, actor_id)
      else
        [actor_id | selected]
      end
    
    socket = assign(socket, :selected_actor_ids, selected)
    {:noreply, socket}
  end
  
  def handle_event("create_actor", params, socket) do
    attrs = %{
      first_name: params["first_name"],
      last_name: params["last_name"]
    }
    
    case FilmCone.Repo.insert(Actor.changeset(%Actor{}, attrs)) do
      {:ok, actor} ->
        selected = [actor.actor_id | socket.assigns.selected_actor_ids]
        all_actors = list_all_actors()
        
        socket =
          socket
          |> assign(:selected_actor_ids, selected)
          |> assign(:available_actors, all_actors)
          |> put_flash(:info, "Actor created and added!")
        
        {:noreply, socket}
        
      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Failed to create actor")
        {:noreply, socket}
    end
  end
  
  def handle_event("save_actors", _params, socket) do
    film = socket.assigns.selected_film
    
    # Delete existing associations
    from(fa in FilmActor, where: fa.film_id == ^film.film_id)
    |> FilmCone.Repo.delete_all()
    
    # Create new associations
    Enum.each(socket.assigns.selected_actor_ids, fn actor_id ->
      FilmCone.Repo.insert!(%FilmActor{
        film_id: film.film_id,
        actor_id: actor_id
      })
    end)
    
    actors = list_film_actors(film.film_id)
    
    socket =
      socket
      |> assign(:actors, actors)
      |> assign(:form_mode, nil)
      |> put_flash(:info, "Actors updated successfully!")
    
    {:noreply, socket}
  end
  
  def handle_event("remove_actor", %{"actor-id" => actor_id}, socket) do
    film = socket.assigns.selected_film
    actor_id = String.to_integer(actor_id)
    
    from(fa in FilmActor, 
      where: fa.film_id == ^film.film_id and fa.actor_id == ^actor_id)
    |> FilmCone.Repo.delete_all()
    
    actors = list_film_actors(film.film_id)
    
    socket =
      socket
      |> assign(:actors, actors)
      |> put_flash(:info, "Actor removed from film")
    
    {:noreply, socket}
  end
  
  def handle_event("cancel_form", _params, socket) do
    socket = 
      socket
      |> assign(:form_mode, nil)
      |> assign(:changeset, nil)
    
    {:noreply, socket}
  end
  
  # Private Functions
  
  defp list_films do
    Film
    |> order_by([f], desc: f.film_id)
    |> limit(100)
    |> FilmCone.Repo.all()
  end
  
  defp list_film_actors(film_id) do
    from(a in Actor,
      join: fa in FilmActor, on: fa.actor_id == a.actor_id,
      where: fa.film_id == ^film_id,
      order_by: [a.first_name, a.last_name]
    )
    |> FilmCone.Repo.all()
  end
  
  defp list_all_actors do
    Actor
    |> order_by([a], [a.first_name, a.last_name])
    |> limit(200)
    |> FilmCone.Repo.all()
  end
  
  defp search_actors(""), do: list_all_actors()
  defp search_actors(search) do
    pattern = "%#{search}%"
    
    from(a in Actor,
      where: ilike(a.first_name, ^pattern) or ilike(a.last_name, ^pattern),
      order_by: [a.first_name, a.last_name],
      limit: 50
    )
    |> FilmCone.Repo.all()
  end
  
  defp calculate_stats(films) do
    total_actors = FilmCone.Repo.aggregate(Actor, :count)
    
    avg = 
      case FilmCone.Repo.aggregate(FilmActor, :count) do
        0 -> 0
        count -> Float.round(count / max(length(films), 1), 1)
      end
    
    %{
      total_films: length(films),
      total_actors: total_actors,
      avg_actors_per_film: avg
    }
  end
end

# Start the application
{:ok, _} = FilmCone.Repo.start_link([])

port = String.to_integer(System.get_env("PORT", "4100"))

PhoenixPlayground.start(
  live: FilmCone.ConeLive,
  port: port,
  open: false,
  live_reload: true
)

IO.puts """

🎬 FilmCone Server Started with Phoenix Playground!
📍 Visit: http://localhost:#{port}
⏹  Press Ctrl+C twice to stop

Features:
• Create new films with full metadata
• Associate existing actors with films  
• Create new actors on the fly
• Remove actors from films
• Search actors by name

"""

Process.sleep(:infinity)