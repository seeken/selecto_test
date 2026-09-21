# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Available Tools

**AST-Grep**: This project has ast-grep configured for advanced code searching and refactoring.
```bash
# Search for patterns
ast-grep --pattern 'Selecto.execute($$$)' --lang elixir
ast-grep --pattern 'Mix.env()' --lang elixir
ast-grep --pattern '{:error, $ERROR}' --lang elixir

# Run configured rules
ast-grep scan                    # Scan with all rules
ast-grep scan --rule no-mix-env-in-runtime  # Run specific rule

# Configuration files:
# - .ast-grep/rules.yml - Project-specific rules and patterns
# - .ast-grep/sgconfig.yml - AST-grep configuration
```

## Development Commands

**Setup and Dependencies:**
```bash
# Initial setup (includes deps.get, ecto.setup, assets setup/build)
mix setup

# Get dependencies only
mix deps.get

# Database operations
mix ecto.create
mix ecto.migrate
mix ecto.reset  # drops and recreates database
mix run priv/repo/seeds.exs
```

**Development Server:**
```bash
# Start Phoenix server (localhost only)
mix phx.server

# Start with IEx console (required for Livebook connection)
iex --sname selecto --cookie COOKIE -S mix phx.server

# Bind to all interfaces (0.0.0.0) for remote access
BIND_ALL_INTERFACES=true mix phx.server
BIND_ALL_INTERFACES=true iex --sname selecto --cookie COOKIE -S mix phx.server
```

**Assets:**
```bash
# Setup assets (Tailwind + esbuild)
mix assets.setup

# Build assets for development (includes colocated hook extraction)
mix assets.build

# Build and minify for production (includes colocated hook extraction)
mix assets.deploy

# Manual colocated hook extraction (happens automatically during assets.build/deploy)
mix compile
```

**Testing:**
```bash
# Run tests (includes database setup)
mix test

# Run specific test files with timeout
timeout 30 mix test test/specific_test.exs --max-cases 1
```

## Production Debug Panel

The debug panel can be enabled in production with proper security measures:

**Security Requirements:**
1. Two environment variables must be set
2. A secure token must be provided via query parameter or session
3. Debug panel is completely disabled without both requirements

**To Enable Debug Panel in Production:**
```bash
# Generate secure configuration (creates a random token)
./scripts/enable_production_debug.sh

# Set Fly.io secrets (use the token from the script output)
fly secrets set SELECTO_DEBUG_ENABLED=true
fly secrets set SELECTO_DEBUG_TOKEN="<your-secure-token>"

# Access with token in URL
https://your-app.fly.dev/pagila?debug_token=<your-secure-token>
```

**To Disable Debug Panel:**
```bash
fly secrets unset SELECTO_DEBUG_ENABLED SELECTO_DEBUG_TOKEN
```

**Security Features:**
- Requires BOTH `SELECTO_DEBUG_ENABLED=true` AND a valid `SELECTO_DEBUG_TOKEN`
- Token comparison uses constant-time algorithm to prevent timing attacks
- Debug panel completely hidden without valid authentication
- Automatically enabled in dev/test environments without token

## Architecture Overview

This is a Phoenix LiveView application that serves as a test/development environment for the Selecto ecosystem. The app provides dynamic data visualization interfaces for the Pagila sample database.

**Important:** This project is co-developed with sibling Selecto repositories:
- `selecto` - Core query builder library with advanced SQL generation, joins, CTEs, and OLAP functions
- `selecto_db_postgresql_postgis` - PostGIS extension package for spatial domain metadata, overlay DSL, and map view integration
- `selecto_views` - Self-contained Phoenix LiveView Explorer for interactive data visualization
- `selecto_dome` (v0.1.0) - Data manipulation interface for Selecto query results
- `selecto_mix` (v0.1.0) - Mix tasks and generators for Selecto domain configuration
- `selecto_kino` - Livebook integration for interactive querying

When making changes, you may need to modify code across multiple projects to maintain compatibility.

### Key Dependencies
- **Selecto**: Advanced query builder with comprehensive join support, CTEs, hierarchical queries, and OLAP functions
- **SelectoViews**: Self-contained detail, aggregate, and graph Explorer with drill-down navigation
- **SelectoDome** (v0.1.0): Data manipulation and change tracking interface
- **SelectoMix**: Code generation tools for domains and schemas
- **Phoenix LiveView**: Powers the reactive UI components (v1.1+)
- **Ecto**: Database operations with PostgreSQL (v3.12+)
- **Tailwind CSS**: Host application styling; the Explorer serves its own packaged CSS
- **Timex**: Date/time handling in the host application
- **UUID**: Identifier generation for saved views and components

### Core Architecture

**Domain Layer (`lib/selecto_test/`):**
- `PagilaDomain` & `PagilaDomainFilms`: Rich domain configurations with custom columns, filters, and join relationships
- `Store/`: Comprehensive Ecto schemas for Pagila database tables (Film, Actor, Category, Customer, etc.)
- `Blog/`: Additional domain schemas for testing (Author, Post, Category, Comment, BlogTag)
- `Test/`: Solar system test domain (SolarSystem, Planet, Satellite)
- `SavedView` & `SavedViewContext`: Persistent view configurations with context-based organization
- `Seed`: Database seeding utilities

**Web Layer (`lib/selecto_test_web/`):**
- `PagilaLive`: Main LiveView with multi-domain routing (:index for actors, :films for films, :stores)
- `PagilaFilmLive`: Dedicated film detail view
- Uses `SelectoViews.Explorer` for dynamic data visualization and interaction
- Supports multiple view types: Aggregate (with drill-down), Detail, and Graph views
- Custom components in `components/` for layouts and core UI elements

**Data Flow:**
1. LiveView configures Selecto with domain-specific schemas and Postgrex connection
2. `SelectoViews.Explorer` owns staged query state, filtering, aggregation, execution, and results
3. Views support drill-down navigation between aggregate and detail modes
4. Custom filters and columns enable advanced data exploration

### Database Schema
- **Pagila Database**: Film rental store with Actor, Film, Category, Customer, Rental, Inventory, Staff, Store entities
- **Custom Extensions**: `saved_views`, `tags`, `flags`, and `film_tag`/`film_flag` junction tables
- **Blog Domain**: Author, Post, Category, Comment relationships for testing complex domains
- **Test Domains**: Solar system hierarchy (SolarSystem → Planet → Satellite)
- **Migration Strategy**: Schema loaded externally, with custom tables added via migrations

### Asset Pipeline
- **Tailwind CSS**: Host application configuration; Explorer CSS is served from `selecto_views`
- **JavaScript Integration**: 
  - **Colocated Hooks**: Phoenix LiveView 1.1+ colocated hooks for app-level LiveViews
  - **App Hooks**: Keep only truly app-specific hooks in `assets/js/hooks/`
- **Build Process**: esbuild + Tailwind with development and production targets
- **Colocated Hook Compilation**: Hooks are automatically extracted during `mix compile` to `_build/{env}/phoenix-colocated/`

### Routes & Navigation
- `/` and `/pagila`: Actor domain interface with film relationships
- `/pagila_films`: Film-centric domain with ratings and categorization
- `/pagila_stores`: Store management interface (planned)
- `/pagila/film/:film_id`: Individual film detail pages
- **Development Routes**: LiveDashboard at `/dev/dashboard`, Swoosh mailbox preview

### Testing Infrastructure
- **Comprehensive Test Suite**: 30+ test files covering core functionality, integrations, and edge cases
- **Selecto Core Tests**: Query building, filtering, joins, CTEs, and OLAP functions
- **Dome Integration**: Database operations and change tracking
- **Test Support**: Custom test cases, helpers, and database connection utilities
- **Performance Testing**: Benchmarking and memory profiling capabilities

### Development Features
- **Livebook Integration**: `notebooks/` directory with comprehensive demos and tutorials
- **Code Generation**: Mix tasks for domain and schema generation via SelectoMix
- **Documentation**: Extensive guides for joins, OLAP patterns, and advanced usage
- **Multi-Environment**: Development, test, and production configurations with Docker support
- remember to always use case insensitive tests for SQL keywords
- remember that selecto and all the other items in vendor/ are in scope
- when adding code, make sure it does not create warnings
