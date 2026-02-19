defmodule SelectoTest.Repo.Migrations.CreatePagilaSchema do
  use Ecto.Migration

  def up do
    # Execute the Pagila schema SQL file via psql command
    pagila_schema_file = Path.join([__DIR__, "..", "..", "sql", "pagila-schema.sql"])

    # Get database config
    repo_config = SelectoTest.Repo.config()
    database = repo_config[:database]
    username = repo_config[:username] || "postgres"
    hostname = repo_config[:hostname] || "localhost"
    port = repo_config[:port] || 5432

    # Use psql to execute the SQL file
    psql_cmd =
      ~s(PGPASSWORD="#{repo_config[:password]}" psql -h #{hostname} -p #{port} -U #{username} -d #{database} -f #{pagila_schema_file})

    case System.cmd("sh", ["-c", psql_cmd], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("✓ Pagila schema loaded successfully")
        IO.puts(output)

      {output, exit_code} ->
        IO.puts("⚠ Error loading Pagila schema (exit code: #{exit_code})")
        IO.puts(output)
        # Don't fail the migration if psql isn't available - fallback to basic tables
        execute("CREATE TYPE mpaa_rating AS ENUM ('G', 'PG', 'PG-13', 'R', 'NC-17')")
        create_basic_pagila_schema()
    end
  end

  defp create_basic_pagila_schema do
    # Create essential Pagila tables if psql execution fails
    execute(
      "CREATE TABLE IF NOT EXISTS language (language_id SERIAL PRIMARY KEY, name VARCHAR(20) NOT NULL, last_update TIMESTAMP DEFAULT NOW())"
    )

    execute("""
    CREATE TABLE IF NOT EXISTS actor (
      actor_id SERIAL PRIMARY KEY,
      first_name VARCHAR(45) NOT NULL,
      last_name VARCHAR(45) NOT NULL,
      last_update TIMESTAMP DEFAULT NOW()
    )
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS category (
      category_id SERIAL PRIMARY KEY,
      name VARCHAR(25) NOT NULL,
      last_update TIMESTAMP DEFAULT NOW()
    )
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS film (
      film_id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      description TEXT,
      release_year INTEGER,
      language_id INTEGER REFERENCES language(language_id),
      rental_duration INTEGER DEFAULT 3,
      rental_rate DECIMAL(4,2) DEFAULT 4.99,
      length INTEGER,
      replacement_cost DECIMAL(5,2) DEFAULT 19.99,
      rating mpaa_rating DEFAULT 'G',
      special_features TEXT[],
      last_update TIMESTAMP DEFAULT NOW()
    )
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS film_actor (
      actor_id INTEGER REFERENCES actor(actor_id),
      film_id INTEGER REFERENCES film(film_id),
      last_update TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (actor_id, film_id)
    )
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS film_category (
      film_id INTEGER REFERENCES film(film_id),
      category_id INTEGER REFERENCES category(category_id),
      last_update TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (film_id, category_id)
    )
    """)

    IO.puts("✓ Basic Pagila schema created as fallback")
  end

  # def change do
  #   # Language table
  #   create table(:language, primary_key: false) do
  #     add :language_id, :serial, primary_key: true
  #     add :name, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Actor table
  #   create table(:actor, primary_key: false) do
  #     add :actor_id, :serial, primary_key: true
  #     add :first_name, :string, null: false
  #     add :last_name, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Category table
  #   create table(:category, primary_key: false) do
  #     add :category_id, :id, primary_key: true
  #     add :name, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Country table
  #   create table(:country, primary_key: false) do
  #     add :country_id, :id, primary_key: true
  #     add :country, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # City table
  #   create table(:city, primary_key: false) do
  #     add :city_id, :id, primary_key: true
  #     add :city, :string, null: false
  #     add :country_id, references(:country, column: :country_id), null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Address table
  #   create table(:address, primary_key: false) do
  #     add :address_id, :id, primary_key: true
  #     add :address, :string, null: false
  #     add :address2, :string
  #     add :district, :string, null: false
  #     add :city_id, references(:city, column: :city_id), null: false
  #     add :postal_code, :string
  #     add :phone, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Store table
  #   create table(:store, primary_key: false) do
  #     add :store_id, :id, primary_key: true
  #     add :manager_staff_id, :integer, null: false
  #     add :address_id, references(:address, column: :address_id), null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Staff table
  #   create table(:staff, primary_key: false) do
  #     add :staff_id, :id, primary_key: true
  #     add :first_name, :string, null: false
  #     add :last_name, :string, null: false
  #     add :address_id, references(:address, column: :address_id), null: false
  #     add :email, :string
  #     add :store_id, references(:store, column: :store_id), null: false
  #     add :active, :boolean, default: true
  #     add :username, :string, null: false
  #     add :password, :string
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Customer table
  #   create table(:customer, primary_key: false) do
  #     add :customer_id, :id, primary_key: true
  #     add :store_id, references(:store, column: :store_id), null: false
  #     add :first_name, :string, null: false
  #     add :last_name, :string, null: false
  #     add :email, :string
  #     add :address_id, references(:address, column: :address_id), null: false
  #     add :activebool, :boolean, default: true
  #     add :create_date, :date, default: fragment("CURRENT_DATE")
  #     add :active, :integer
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Film table
  #   create table(:film, primary_key: false) do
  #     add :film_id, :serial, primary_key: true
  #     add :title, :string, null: false
  #     add :description, :text
  #     add :release_year, :integer
  #     add :language_id, references(:language, column: :language_id), null: false
  #     add :rental_duration, :integer, default: 3, null: false
  #     add :rental_rate, :decimal, precision: 4, scale: 2, default: 4.99, null: false
  #     add :length, :integer
  #     add :replacement_cost, :decimal, precision: 5, scale: 2, default: 19.99, null: false
  #     add :rating, :string, default: "G"
  #     add :special_features, {:array, :string}
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Film Actor junction table
  #   create table(:film_actor, primary_key: false) do
  #     add :actor_id, references(:actor, column: :actor_id), null: false
  #     add :film_id, references(:film, column: :film_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Film Category junction table
  #   create table(:film_category, primary_key: false) do
  #     add :film_id, references(:film, column: :film_id), null: false
  #     add :category_id, references(:category, column: :category_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Inventory table
  #   create table(:inventory, primary_key: false) do
  #     add :inventory_id, :id, primary_key: true
  #     add :film_id, references(:film, column: :film_id), null: false
  #     add :store_id, references(:store, column: :store_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Rental table
  #   create table(:rental, primary_key: false) do
  #     add :rental_id, :id, primary_key: true
  #     add :rental_date, :utc_datetime, null: false
  #     add :inventory_id, references(:inventory, column: :inventory_id), null: false
  #     add :customer_id, references(:customer, column: :customer_id), null: false
  #     add :return_date, :utc_datetime
  #     add :staff_id, references(:staff, column: :staff_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Payment table
  #   create table(:payment, primary_key: false) do
  #     add :payment_id, :id, primary_key: true
  #     add :customer_id, references(:customer, column: :customer_id), null: false
  #     add :staff_id, references(:staff, column: :staff_id), null: false
  #     add :rental_id, references(:rental, column: :rental_id)
  #     add :amount, :decimal, precision: 5, scale: 2, null: false
  #     add :payment_date, :utc_datetime, null: false
  #   end

  #   # Create composite primary keys for junction tables
  #   create unique_index(:film_actor, [:actor_id, :film_id])
  #   create unique_index(:film_category, [:film_id, :category_id])

  #   # Create indexes for foreign keys
  #   create index(:city, [:country_id])
  #   create index(:address, [:city_id])
  #   create index(:store, [:address_id])
  #   create index(:staff, [:address_id, :store_id])
  #   create index(:customer, [:store_id, :address_id])
  #   create index(:film, [:language_id])
  #   create index(:film_actor, [:actor_id])
  #   create index(:film_actor, [:film_id])
  #   create index(:film_category, [:film_id])
  #   create index(:film_category, [:category_id])
  #   create index(:inventory, [:film_id, :store_id])
  #   create index(:rental, [:inventory_id, :customer_id, :staff_id])
  #   create index(:payment, [:customer_id, :staff_id, :rental_id])
  # end
end
