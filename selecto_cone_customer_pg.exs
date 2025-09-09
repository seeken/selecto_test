#!/usr/bin/env elixir

# SelectoCone LiveView with Phoenix Playground
# Generated 2025-09-08
# 
# Hierarchical data management pattern:
# - Customer (Apex/Root)
# - Rental (Middle Layer)
# - Payment (Base Layer)
#
# Usage: mix run selecto_cone_customer_pg.exs

# Check if we're in a Mix project
in_mix_project = File.exists?("mix.exs")

unless in_mix_project do
  Mix.install([
    {:phoenix_playground, "~> 0.1.7"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, "~> 0.17"}
  ])
end

# Configure database connection
Application.put_env(:selecto_cone, SelectoCone.Repo,
  database: System.get_env("DB_NAME", "selecto_test_dev"),
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  pool_size: 10
)

defmodule SelectoCone.Repo do
  use Ecto.Repo,
    otp_app: :selecto_cone,
    adapter: Ecto.Adapters.Postgres
end

# Import your schema modules
# Update these aliases to match your application structure
alias Elixir.SelectoTest.Store.Customer
alias Elixir.SelectoTest.Store.Rental
alias Elixir.SelectoTest.Store.Payment


defmodule CustomerCone.ConeLive do
  use Phoenix.LiveView
  use Phoenix.Component
  import Phoenix.HTML.Form
  import Ecto.Query
  
  @impl true
  def mount(_params, _session, socket) do
    customers = list_customers()
    
    socket =
      socket
      |> assign(:customers, customers)
      |> assign(:selected_customer, nil)
      |> assign(:rentals, [])
      |> assign(:selected_rental, nil)
      |> assign(:payments, [])
      |> assign(:form_mode, nil)
          |> assign(:changeset, nil)
      |> assign(:stats, calculate_stats(customers))
    
    {:ok, socket}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
        customer_id = params["customer_id"]
    rental_id = params["rental_id"]
    
    socket =
      socket
      |> load_customer(customer_id)
      |> load_rental(rental_id)

    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family: system-ui, -apple-system, sans-serif; max-width: 1400px; margin: 0 auto; padding: 2rem;">
      <h1 style="font-size: 2rem; font-weight: bold; margin-bottom: 2rem;">
        SelectoCone - Customer Management
      </h1>
      
      <!-- Stats Dashboard -->
      <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 2rem;">
        <div style="background: #EBF8FF; padding: 1rem; border-radius: 0.5rem;">
          <div style="color: #718096; font-size: 0.875rem;">Total Customers</div>
          <div style="font-size: 1.5rem; font-weight: bold;"><%= @stats.total_customers %></div>
        </div>
        <div style="background: #F0FDF4; padding: 1rem; border-radius: 0.5rem;">
          <div style="color: #718096; font-size: 0.875rem;">Active Rentals</div>
          <div style="font-size: 1.5rem; font-weight: bold;"><%= @stats.active_rentals %></div>
        </div>

      </div>

      
      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1.5rem;">
        <!-- Customers (Apex) -->
        <div style="background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <h2 style="font-size: 1.25rem; font-weight: 600;">Customers (Apex)</h2>
            <button phx-click="new_customer" style="background: #3B82F6; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer;">
  + New
</button>

          </div>
          
          <div style="max-height: 24rem; overflow-y: auto;">
            <%= for customer <- @customers do %>
              <div
                phx-click="select_customer"
                phx-value-id={customer.customer_id}
                style={"padding: 0.75rem; margin-bottom: 0.5rem; border: 1px solid #E5E7EB; border-radius: 0.25rem; cursor: pointer; #{if @selected_customer && @selected_customer.customer_id == customer.customer_id, do: "background: #DBEAFE; border-color: #3B82F6;", else: "background: white;"}"}
              >
                <div style="font-weight: 500;">
                  Customer #<%= customer.customer_id %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Rentals (Middle) -->
        <div style="background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <h2 style="font-size: 1.25rem; font-weight: 600;">Rentals (Middle)</h2>
            <%= if @selected_customer do %>
              <button phx-click="new_rental" style="background: #10B981; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer;">
  + New
</button>

            <% end %>
          </div>
          
          <%= if @selected_customer do %>
            <div style="max-height: 24rem; overflow-y: auto;">
              <%= for rental <- @rentals do %>
                <div
                  phx-click="select_rental"
                  phx-value-id={rental.rental_id}
                  style={"padding: 0.75rem; margin-bottom: 0.5rem; border: 1px solid #E5E7EB; border-radius: 0.25rem; cursor: pointer; #{if @selected_rental && @selected_rental.rental_id == rental.rental_id, do: "background: #D1FAE5; border-color: #10B981;", else: "background: white;"}"}
                >
                  <div style="font-weight: 500;">
                    Rental #<%= rental.rental_id %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <div style="text-align: center; color: #9CA3AF; padding: 4rem 0;">
              Select a customer to view rentals
            </div>
          <% end %>
        </div>

        <!-- Payments (Base) -->
        <div style="background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <h2 style="font-size: 1.25rem; font-weight: 600;">Payments (Base)</h2>
            <%= if @selected_rental do %>
              <button phx-click="new_payment" style="background: #8B5CF6; color: white; padding: 0.25rem 0.75rem; border-radius: 0.25rem; border: none; cursor: pointer;">
  + New
</button>

            <% end %>
          </div>
          
          <%= if @selected_rental do %>
            <div style="max-height: 24rem; overflow-y: auto;">
              <%= for payment <- @payments do %>
                <div style="padding: 0.75rem; margin-bottom: 0.5rem; border: 1px solid #E5E7EB; border-radius: 0.25rem; background: white;">
                  <div style="font-weight: 500;">
                    Payment #<%= payment.payment_id %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <div style="text-align: center; color: #9CA3AF; padding: 4rem 0;">
              Select a rental to view payments
            </div>
          <% end %>
        </div>

      </div>
      
      <!-- Form Modal Placeholder -->
      <%= if @form_mode do %>
        <div style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 50;">
          <div style="background: white; border-radius: 0.5rem; padding: 1.5rem; width: 24rem;">
            <h3 style="font-size: 1.125rem; font-weight: 600; margin-bottom: 1rem;">
              Form Modal
            </h3>
            <p>Form implementation goes here</p>
            <button phx-click="cancel_form" style="background: #9CA3AF; color: white; padding: 0.5rem 1rem; border-radius: 0.25rem; border: none; cursor: pointer;">
              Cancel
            </button>
          </div>
        </div>
      <% end %>

    </div>
    """
  end
  
  # Event Handlers
  
  @impl true
  def handle_event("select_customer", %{"id" => id}, socket) do
    socket = load_customer(socket, id)
    {:noreply, push_patch(socket, to: "/?customer_id=#{id}")}
  end
  
  @impl true
  def handle_event("select_rental", %{"id" => id}, socket) do
    socket = load_rental(socket, id)
    customer_id = socket.assigns.selected_customer.customer_id
    {:noreply, push_patch(socket, to: "/?customer_id=#{customer_id}&rental_id=#{id}")}
  end

  
  @impl true
  def handle_event("new_customer", _params, socket) do
    socket = assign(socket, :form_mode, :new_customer)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("cancel_form", _params, socket) do
    socket = 
      socket
      |> assign(:form_mode, nil)
      |> assign(:changeset, nil)
    
    {:noreply, socket}
  end


  
  # Private Functions
  
  defp list_customers do
    Elixir.SelectoTest.Store.Customer
    |> order_by([t], t.customer_id)
    |> limit(100)
    |> SelectoCone.Repo.all()
  end
  
  defp load_customer(socket, nil), do: socket
  defp load_customer(socket, customer_id) do
    customer = SelectoCone.Repo.get!(Elixir.SelectoTest.Store.Customer, customer_id)
    rentals = list_rentals(customer.customer_id)
    
    socket
    |> assign(:selected_customer, customer)
    |> assign(:rentals, rentals)
        |> assign(:selected_rental, nil)
    |> assign(:payments, [])
  end
  
  defp list_rentals(customer_id) do
    Elixir.SelectoTest.Store.Rental
    |> where([t], t.customer_id == ^customer_id)
    |> order_by([t], desc: t.rental_id)
    |> SelectoCone.Repo.all()
  end
  
  defp load_rental(socket, nil), do: socket
  defp load_rental(socket, rental_id) do
    rental = SelectoCone.Repo.get!(Elixir.SelectoTest.Store.Rental, rental_id)
    payments = list_payments(rental.rental_id)
    
    socket
    |> assign(:selected_rental, rental)
    |> assign(:payments, payments)
  end
  
  defp list_payments(rental_id) do
    Elixir.SelectoTest.Store.Payment
    |> where([t], t.rental_id == ^rental_id)
    |> order_by([t], desc: t.payment_id)
    |> SelectoCone.Repo.all()
  end


  
  defp calculate_stats(customers) do
    %{
      total_customers: length(customers),
          active_rentals: 0
    }
  end


end

# Start the application
{:ok, _} = SelectoCone.Repo.start_link()

# Start Phoenix Playground
port = 4101

PhoenixPlayground.start(
  live: CustomerCone.ConeLive,
  port: port
)

IO.puts """

🚀 SelectoCone Server Started!
📍 Visit: http://localhost:4101/
⏹  Press Ctrl+C twice to stop

Hierarchy:
• Customer (Apex - all operations flow through here)
• Rental (Middle layer)
• Payment (Base layer)

"""
