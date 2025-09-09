#!/usr/bin/env elixir

# SelectoCone LiveView - Film->Actor Management
# 
# Hierarchical data management pattern:
# - Film (Apex/Root) - All operations flow through films
# - FilmActor (Junction) - Links films to actors
# - Actor (Associated) - Can be created or selected
#
# Usage: PORT=4098 mix run film_actor_cone.exs

# Check if we're in a Mix project
in_mix_project = File.exists?("mix.exs")

unless in_mix_project do
  Mix.install([
    {:phoenix, "~> 1.7"},
    {:phoenix_live_view, "~> 1.0"},
    {:plug_cowboy, "~> 2.5"},
    {:jason, "~> 1.4"},
    {:phoenix_html, "~> 4.0"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, "~> 0.17"}
  ])
end

Application.put_env(:film_cone, FilmCone.Endpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: String.duplicate("a", 8)],
  http: [port: String.to_integer(System.get_env("PORT", "4098"))],
  server: true,
  render_errors: [
    formats: [html: FilmCone.ErrorHTML, json: FilmCone.ErrorJSON],
    layout: false
  ],
  pubsub_server: FilmCone.PubSub,
  check_origin: false
)

# Configure your database connection here
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

# Import your schema modules
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
    all_actors = list_all_actors()
    
    socket =
      socket
      |> assign(:films, films)
      |> assign(:selected_film, nil)
      |> assign(:film_actors, [])
      |> assign(:all_actors, all_actors)
      |> assign(:form_mode, nil)
      |> assign(:changeset, nil)
      |> assign(:selected_actor_ids, [])
      |> assign(:stats, calculate_stats(films))
    
    {:ok, socket}
  end
  
  def handle_params(params, _url, socket) do
    film_id = params["film_id"]
    
    socket =
      socket
      |> load_film(film_id)

    {:noreply, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div style="font-family: system-ui, -apple-system, sans-serif; max-width: 1400px; margin: 0 auto; padding: 2rem;">
      <h1 style="font-size: 2rem; font-weight: bold; margin-bottom: 2rem;">
        FilmCone - Film & Actor Management
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
          <div style="color: #718096; font-size: 0.875rem;">Avg Actors per Film</div>
          <div style="font-size: 1.5rem; font-weight: bold;"><%= @stats.avg_actors_per_film %></div>
        </div>
      </div>

      
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem;">
        <!-- Films (Apex) -->
        <div style="background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <h2 style="font-size: 1.25rem; font-weight: 600;">Films (Apex)</h2>
            <button phx-click="new_film" style="background: #3B82F6; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer;">
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
                <div style="font-weight: 500;">
                  <%= film.title %>
                </div>
                <div style="color: #6B7280; font-size: 0.875rem;">
                  <%= film.release_year || "No year" %> • <%= film.rating || "Not rated" %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Actors (Associated) -->
        <div style="background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <h2 style="font-size: 1.25rem; font-weight: 600;">Actors in Film</h2>
            <%= if @selected_film do %>
              <button phx-click="add_actors" style="background: #10B981; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer;">
                + Add Actors
              </button>
            <% end %>
          </div>
          
          <%= if @selected_film do %>
            <div style="max-height: 32rem; overflow-y: auto;">
              <%= if length(@film_actors) > 0 do %>
                <%= for actor <- @film_actors do %>
                  <div style="padding: 0.75rem; margin-bottom: 0.5rem; border: 1px solid #E5E7EB; border-radius: 0.25rem; background: white; display: flex; justify-content: space-between; align-items: center;">
                    <div>
                      <div style="font-weight: 500;">
                        <%= actor.first_name %> <%= actor.last_name %>
                      </div>
                      <div style="color: #6B7280; font-size: 0.875rem;">
                        Actor ID: <%= actor.actor_id %>
                      </div>
                    </div>
                    <button 
                      phx-click="remove_actor" 
                      phx-value-actor-id={actor.actor_id}
                      style="background: #EF4444; color: white; padding: 0.25rem 0.5rem; border-radius: 0.25rem; border: none; cursor: pointer; font-size: 0.875rem;">
                      Remove
                    </button>
                  </div>
                <% end %>
              <% else %>
                <div style="text-align: center; color: #9CA3AF; padding: 2rem 0;">
                  No actors in this film yet
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
      <%= if @form_mode do %>
        <div style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 50;">
          <div style="background: white; border-radius: 0.5rem; padding: 1.5rem; width: 32rem; max-height: 80vh; overflow-y: auto;">
            <%= case @form_mode do %>
              <% :new_film -> %>
                <h3 style="font-size: 1.125rem; font-weight: 600; margin-bottom: 1rem;">
                  New Film
                </h3>
                <.form for={@changeset} phx-submit="save_film">
                  <div style="margin-bottom: 1rem;">
                    <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                      Title *
                    </label>
                    <input 
                      type="text" 
                      name="film[title]" 
                      required 
                      style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                    />
                  </div>
                  
                  <div style="margin-bottom: 1rem;">
                    <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                      Description
                    </label>
                    <textarea 
                      name="film[description]" 
                      rows="3"
                      style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                    ></textarea>
                  </div>
                  
                  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1rem;">
                    <div>
                      <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                        Release Year
                      </label>
                      <input 
                        type="number" 
                        name="film[release_year]" 
                        min="1900" 
                        max="2100"
                        style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                      />
                    </div>
                    
                    <div>
                      <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                        Rating
                      </label>
                      <select 
                        name="film[rating]"
                        style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                      >
                        <option value="">Select rating</option>
                        <option value="G">G</option>
                        <option value="PG">PG</option>
                        <option value="PG-13">PG-13</option>
                        <option value="R">R</option>
                        <option value="NC-17">NC-17</option>
                      </select>
                    </div>
                  </div>
                  
                  <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin-bottom: 1rem;">
                    <div>
                      <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                        Rental Duration *
                      </label>
                      <input 
                        type="number" 
                        name="film[rental_duration]" 
                        required
                        value="3"
                        min="1"
                        style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                      />
                    </div>
                    
                    <div>
                      <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                        Rental Rate *
                      </label>
                      <input 
                        type="number" 
                        name="film[rental_rate]" 
                        required
                        value="4.99"
                        step="0.01"
                        min="0"
                        style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                      />
                    </div>
                    
                    <div>
                      <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                        Replacement Cost *
                      </label>
                      <input 
                        type="number" 
                        name="film[replacement_cost]" 
                        required
                        value="19.99"
                        step="0.01"
                        min="0"
                        style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                      />
                    </div>
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
                      Save Film
                    </button>
                  </div>
                </.form>
                
              <% :add_actors -> %>
                <h3 style="font-size: 1.125rem; font-weight: 600; margin-bottom: 1rem;">
                  Add Actors to <%= @selected_film.title %>
                </h3>
                
                <div style="margin-bottom: 1rem;">
                  <label style="display: block; font-size: 0.875rem; font-weight: 500; margin-bottom: 0.25rem;">
                    Search and Select Actors
                  </label>
                  <input 
                    type="text" 
                    phx-keyup="search_actors"
                    placeholder="Type to search actors..."
                    style="width: 100%; padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem; margin-bottom: 0.5rem;"
                  />
                  
                  <div style="max-height: 16rem; overflow-y: auto; border: 1px solid #E5E7EB; border-radius: 0.25rem; padding: 0.5rem;">
                    <%= for actor <- @all_actors do %>
                      <label style="display: flex; align-items: center; padding: 0.5rem; cursor: pointer; hover: background-color: #F3F4F6;">
                        <input 
                          type="checkbox" 
                          phx-click="toggle_actor"
                          phx-value-actor-id={actor.actor_id}
                          checked={actor.actor_id in @selected_actor_ids}
                          style="margin-right: 0.5rem;"
                        />
                        <%= actor.first_name %> <%= actor.last_name %>
                      </label>
                    <% end %>
                  </div>
                </div>
                
                <div style="border-top: 1px solid #E5E7EB; margin: 1rem 0; padding-top: 1rem;">
                  <h4 style="font-weight: 500; margin-bottom: 0.5rem;">Or Add New Actor</h4>
                  <.form for={%{}} phx-submit="create_actor">
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
                      <input 
                        type="text" 
                        name="actor[first_name]" 
                        placeholder="First name"
                        style="padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                      />
                      <input 
                        type="text" 
                        name="actor[last_name]" 
                        placeholder="Last name"
                        style="padding: 0.5rem; border: 1px solid #D1D5DB; border-radius: 0.25rem;"
                      />
                    </div>
                    <button 
                      type="submit"
                      style="background: #8B5CF6; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer; font-size: 0.875rem;">
                      Create & Add Actor
                    </button>
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
                
              <% _ -> %>
                <p>Unknown form mode</p>
            <% end %>
          </div>
        </div>
      <% end %>

    </div>
    """
  end
  
  # Event Handlers
  
  def handle_event("select_film", %{"id" => id}, socket) do
    socket = load_film(socket, id)
    {:noreply, push_patch(socket, to: "/film_cone?film_id=#{id}")}
  end
  
  def handle_event("new_film", _params, socket) do
    changeset = Film.changeset(%Film{}, %{})
    socket = 
      socket
      |> assign(:form_mode, :new_film)
      |> assign(:changeset, changeset)
    {:noreply, socket}
  end
  
  def handle_event("add_actors", _params, socket) do
    existing_actor_ids = Enum.map(socket.assigns.film_actors, & &1.actor_id)
    socket = 
      socket
      |> assign(:form_mode, :add_actors)
      |> assign(:selected_actor_ids, existing_actor_ids)
    {:noreply, socket}
  end
  
  def handle_event("toggle_actor", %{"actor-id" => actor_id}, socket) do
    actor_id = String.to_integer(actor_id)
    selected = socket.assigns.selected_actor_ids
    
    updated = 
      if actor_id in selected do
        List.delete(selected, actor_id)
      else
        [actor_id | selected]
      end
    
    {:noreply, assign(socket, :selected_actor_ids, updated)}
  end
  
  def handle_event("save_film", %{"film" => film_params}, socket) do
    # Set default language_id to 1 (English)
    film_params = Map.put(film_params, "language_id", 1)
    
    case FilmCone.Repo.insert(Film.changeset(%Film{}, film_params)) do
      {:ok, film} ->
        films = list_films()
        socket = 
          socket
          |> assign(:films, films)
          |> assign(:form_mode, nil)
          |> assign(:selected_film, film)
          |> load_film(Integer.to_string(film.film_id))
        
        {:noreply, push_patch(socket, to: "/film_cone?film_id=#{film.film_id}")}
        
      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
  
  def handle_event("save_actors", _params, socket) do
    film = socket.assigns.selected_film
    selected_ids = socket.assigns.selected_actor_ids
    
    # Remove existing associations
    FilmCone.Repo.delete_all(
      from fa in FilmActor,
      where: fa.film_id == ^film.film_id
    )
    
    # Add new associations
    Enum.each(selected_ids, fn actor_id ->
      FilmCone.Repo.insert!(%FilmActor{
        film_id: film.film_id,
        actor_id: actor_id
      })
    end)
    
    socket = 
      socket
      |> load_film(Integer.to_string(film.film_id))
      |> assign(:form_mode, nil)
    
    {:noreply, socket}
  end
  
  def handle_event("create_actor", %{"actor" => actor_params}, socket) do
    case FilmCone.Repo.insert(Actor.changeset(%Actor{}, actor_params)) do
      {:ok, actor} ->
        # Add the new actor to the film
        film = socket.assigns.selected_film
        FilmCone.Repo.insert!(%FilmActor{
          film_id: film.film_id,
          actor_id: actor.actor_id
        })
        
        socket = 
          socket
          |> load_film(Integer.to_string(film.film_id))
          |> assign(:all_actors, list_all_actors())
          |> assign(:form_mode, nil)
        
        {:noreply, socket}
        
      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
  
  def handle_event("remove_actor", %{"actor-id" => actor_id}, socket) do
    film = socket.assigns.selected_film
    actor_id = String.to_integer(actor_id)
    
    FilmCone.Repo.delete_all(
      from fa in FilmActor,
      where: fa.film_id == ^film.film_id and fa.actor_id == ^actor_id
    )
    
    socket = 
      socket
      |> load_film(Integer.to_string(film.film_id))
    
    {:noreply, socket}
  end
  
  def handle_event("cancel_form", _params, socket) do
    socket = 
      socket
      |> assign(:form_mode, nil)
      |> assign(:changeset, nil)
      |> assign(:selected_actor_ids, [])
    
    {:noreply, socket}
  end
  
  def handle_event("search_actors", %{"value" => search}, socket) do
    actors = 
      if search == "" do
        list_all_actors()
      else
        search_term = "%#{search}%"
        Actor
        |> where([a], ilike(a.first_name, ^search_term) or ilike(a.last_name, ^search_term))
        |> order_by([a], [a.first_name, a.last_name])
        |> limit(50)
        |> FilmCone.Repo.all()
      end
    
    {:noreply, assign(socket, :all_actors, actors)}
  end
  
  # Private Functions
  
  defp list_films do
    Film
    |> order_by([f], desc: f.film_id)
    |> limit(100)
    |> FilmCone.Repo.all()
  end
  
  defp list_all_actors do
    Actor
    |> order_by([a], [a.first_name, a.last_name])
    |> limit(200)
    |> FilmCone.Repo.all()
  end
  
  defp load_film(socket, nil), do: socket
  defp load_film(socket, film_id) do
    film = FilmCone.Repo.get!(Film, film_id)
    
    actors = 
      Actor
      |> join(:inner, [a], fa in FilmActor, on: fa.actor_id == a.actor_id)
      |> where([a, fa], fa.film_id == ^film.film_id)
      |> order_by([a], [a.first_name, a.last_name])
      |> FilmCone.Repo.all()
    
    socket
    |> assign(:selected_film, film)
    |> assign(:film_actors, actors)
  end
  
  defp calculate_stats(films) do
    total_actors = FilmCone.Repo.aggregate(Actor, :count)
    
    total_associations = FilmCone.Repo.aggregate(FilmActor, :count)
    total_films = length(films)
    
    avg = 
      if total_films > 0 do
        Float.round(total_associations / total_films, 1)
      else
        0
      end
    
    %{
      total_films: total_films,
      total_actors: total_actors,
      avg_actors_per_film: avg
    }
  end
  

end

# Error handling modules
defmodule FilmCone.ErrorHTML do
  use Phoenix.Component
  
  def render(template, assigns) do
    case template do
      "404.html" -> ~H"<h1>Not Found</h1><p>The page you are looking for does not exist.</p>"
      "500.html" -> ~H"<h1>Internal Server Error</h1><p>Something went wrong.</p>"
      _ -> ~H"<h1>Error</h1><p>An unexpected error occurred.</p>"
    end
  end
end

defmodule FilmCone.ErrorJSON do
  def render(template, _assigns) do
    case template do
      "404.json" -> %{error: "Not Found"}
      "500.json" -> %{error: "Internal Server Error"}
      _ -> %{error: "Unknown Error"}
    end
  end
end

# Router
defmodule FilmCone.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FilmCone.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :browser
    live "/film_cone", FilmCone.ConeLive
  end
end

# Layout
defmodule FilmCone.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()}>
        <title>FilmCone - Film & Actor Management</title>
        <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.7/priv/static/phoenix.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@1.0.0/priv/static/phoenix_live_view.min.js"></script>
        <script type="text/javascript">
          window.addEventListener("DOMContentLoaded", () => {
            let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            let liveSocket = new LiveSocket("/live", Phoenix.Socket, {params: {_csrf_token: csrfToken}});
            liveSocket.connect();
            window.liveSocket = liveSocket;
          });
        </script>
      </head>
      <body style="margin: 0; background: #F3F4F6;">
        <%= @inner_content %>
      </body>
    </html>
    """
  end
end

# Endpoint
defmodule FilmCone.Endpoint do
  use Phoenix.Endpoint, otp_app: :film_cone

  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session,
    store: :cookie,
    key: "_film_cone_key",
    signing_salt: "aaaaaaaa"

  plug FilmCone.Router
end

# Application
defmodule FilmCone.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: FilmCone.PubSub},
      FilmCone.Repo,
      FilmCone.Endpoint
    ]

    opts = [strategy: :one_for_one, name: FilmCone.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# Start the application
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = Application.ensure_all_started(:phoenix_live_view)

FilmCone.Application.start(:normal, [])

port = String.to_integer(System.get_env("PORT", "4098"))
IO.puts """

🎬 FilmCone Server Started!
📍 Visit: http://localhost:#{port}/film_cone
⏹  Press Ctrl+C twice to stop

Features:
• Create new films with full metadata
• Associate existing actors with films
• Create new actors on the fly
• Remove actors from films
• Search actors by name

"""

Process.sleep(:infinity)