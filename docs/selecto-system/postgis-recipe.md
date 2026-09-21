# PostGIS Status

The optional `selecto_db_postgresql_postgis` dependency can still contribute
spatial domain metadata when local ecosystem mode or `SELECTO_ENABLE_POSTGIS`
is enabled.

The current `SelectoViews.Explorer` does not publish a map view, so
`selecto_test` no longer wires the former Components-specific map extension
into its UI. Spatial query and adapter work should be verified in the PostGIS
package until a governed map surface is added to `selecto_views`.
