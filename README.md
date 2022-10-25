# Listable Test Project

This project uses git checkouts to [listable](https://github.com/seeken/listable) and [listable_components_tailwind](https://github.com/seeken/listable_components_tailwind) which it expects to find in the vendor subdir to this dir.

This app provides 3 live views: 

 - / the component interface to edit / run queries
 - /aggregates a test view only of aggregates
 - /detail a test detail view


Projects using listable_components_tailwind should include Tailwind and Alpine.js as is done in this project.

You need to add the push event hook from assets/js/hooks

Plans:
 - bigger database with lots of tables and data



## Get up and running

Optionally change your database name in `dev.exs`.

1. Setup the project with `mix setup`
2. Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
3. Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.



