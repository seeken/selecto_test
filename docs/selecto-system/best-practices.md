# SelectoViews Best Practices

- Keep domain metadata authoritative; never accept browser-selected SQL or adapters.
- Configure Selecto once at the host boundary and pass it to the Explorer.
- Give every Explorer instance a stable, unique component id.
- Preserve the distinction between draft and applied query state.
- Bound result limits and keep SQL debug output opt-in.
- Serve the package stylesheet directly rather than copying it into the host.
- Test the actual database-backed LiveView route, including a component-owned event.
- Keep persistence, authorization, and write execution in host-owned code.

`selecto_views` does not currently replace the former saved/exported-view and
filter-set adapters. Do not imply those capabilities are active until explicit
host contracts are added.
