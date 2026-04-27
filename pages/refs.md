# Refs

The `:ref` directive lets schemas reference other named schemas, enabling
recursive structures (trees, ASTs, linked lists) and cross-module reuse.

## Local refs

Inside a `defschema`, `{:ref, atom}` resolves to the same module's
`get_schema/1` callback. The `defschema` macro rewrites local refs at
expansion to `{:ref, {__MODULE__, atom}}`, so authors don't have to spell
out the module name.

```elixir
defmodule Trees do
  import Peri

  defschema :tree, %{
    value: {:required, :integer},
    children: {:list, {:ref, :tree}}
  }
end

Trees.tree(%{value: 1, children: [%{value: 2, children: []}]})
# => {:ok, %{value: 1, children: [%{value: 2, children: []}]}}
```

## Cross-module refs

Use `{:ref, {Mod, atom}}` to reference a schema from another module. The
target module must export `get_schema/1`, which `defschema` provides
automatically.

```elixir
defmodule MySchemas.Cross do
  import Peri

  defschema :graph, %{
    root: {:ref, {Trees, :tree}},
    related: {:list, {:ref, {Other, :node}}}
  }
end
```

## Cycle protection

Recursive schemas terminate when the data terminates. Pathological inputs
(infinite or near-infinite nesting) are stopped by a runtime depth limit
of 64 ref resolutions, surfaced as a validation error rather than a stack
overflow.

## Integrations

- **JSON Schema export** — refs emit `$ref` + `$defs` entries. The def
  body is the inlined target schema; cycles bottom out at the `$ref`
  reference.
- **Ecto** — refs degrade to `:map` on the changeset side. `Peri.validate/2`
  still resolves the ref properly; the changeset path treats it opaquely.
- **StreamData** — generation expands the ref up to 5 levels deep, then
  yields `nil` to terminate. Sufficient for property tests of recursive
  data; not a substitute for hand-written generators on deep structures.
