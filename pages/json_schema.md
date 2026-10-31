# JSON Schema

Peri can convert schemas to and from JSON Schema (Draft 7) maps. The conversion
is bounded by Peri's schema language, so some JSON Schema semantics are lossy
or return an error rather than being approximated silently.

## Encoding

```elixir
schema = %{
  name: {:required, :string},
  age: {:integer, gte: 0},
  email: {:meta, {:required, :string}, description: "Login email", example: "a@b.io"}
}

Peri.to_json_schema(schema)
# => %{
#   "type" => "object",
#   "properties" => %{
#     "name" => %{"type" => "string"},
#     "age" => %{"type" => "integer", "minimum" => 0},
#     "email" => %{
#       "type" => "string",
#       "description" => "Login email",
#       "examples" => ["a@b.io"]
#     }
#   },
#   "required" => ["name", "email"]
# }
```

Top-level keyword-list schemas are accepted in addition to maps. `{:required,
type, opts}` emits the same property schema as `{:required, type}`; the options
are Peri validation/error options and are not represented in JSON Schema.
`{:schema, type, opts}` and coercion wrappers encode their target schema, but
their Peri-only options and source behavior are omitted. `:atom` and `:atom!`
both encode as JSON strings.

### Metadata

`{:meta, type, opts}` annotations are read during encoding. Recognised keys map
to JSON Schema annotation/format keywords:

| Peri meta key         | JSON Schema key               |
| --------------------- | ----------------------------- |
| `:title`              | `title`                       |
| `:description`        | `description`                 |
| `:example`            | `examples` (wrapped in array) |
| `:examples`           | `examples`                    |
| `:deprecated`         | `deprecated`                  |
| `:default`            | `default`                     |
| `:format`             | `format`                      |
| `:pattern`            | `pattern`                     |
| `:read_only`          | `readOnly`                    |
| `:write_only`         | `writeOnly`                   |
| `:content_encoding`   | `contentEncoding`             |
| `:content_media_type` | `contentMediaType`            |

Unknown keys are dropped from the encoded schema (they remain available to
other tooling that reads `:meta` directly).

### Type mapping

| Peri                                        | JSON Schema                           |
| ------------------------------------------- | ------------------------------------- |
| `:string`, `:integer`, `:float`, `:boolean` | `"type"` keyword                      |
| `:date`, `:time`, `:datetime`               | `"string"` + `"format"`               |
| `{:list, t}`                                | `"array"` + `"items"`                 |
| `{:map, t}`, `{:map, k, v}`                 | `"object"` + `"additionalProperties"` |
| `{:tuple, ts}`                              | fixed-length `"array"`                |
| `{:enum, vs}`                               | `"enum"`                              |
| `{:enum, vs, type: t}`                      | `"type"` of `t` + `"enum"`            |
| `{:literal, v}`                             | `"const"`                             |
| `{:either, {a, b}}`, `{:oneof, ts}`         | `"oneOf"`                             |
| `{:required, t}`                            | adds key to parent `"required"`       |
| `{:required, t, opts}`                      | adds key to parent `"required"`       |
| `{:coerce, target}` and `{:coerce, target, opts}` | target schema, without coercion behavior |
| `{:schema, schema, opts}`                   | wrapped schema                         |
| `{type, gte: n}`                            | `"minimum"`                           |
| `{type, gt: n}`                             | `"exclusiveMinimum"`                  |
| `{:string, {:regex, r}}`                    | `"pattern"`                           |

### Dynamic types

`:dependent`, `:cond`, `:custom`, and `{type, {:transform, _}}` cannot be
expressed statically. Use `:on_unsupported`:

```elixir
Peri.to_json_schema(schema, on_unsupported: :raise)
```

- `:omit` (default) — emit `%{}` (true schema)
- `:true_schema` — same as `:omit`
- `:raise` — raise `Peri.JSONSchema.Encoder.UnsupportedTypeError`

### Excluding annotation keys

Pass `:exclude_meta_keys` with a list of meta keywords to drop from the output.
Useful when the consumer-facing schema should not surface validation defaults:

```elixir
Peri.to_json_schema(
  %{count: {:integer, {:default, 0}}},
  exclude_meta_keys: [:default]
)
# => %{
#   "type" => "object",
#   "properties" => %{"count" => %{"type" => "integer"}}
# }
```

Both the direct `{type, {:default, v}}` form and the `{:meta, type, default: v}`
form honour the exclusion. Any subset of the meta vocabulary above is accepted.

### Typed enums

`{:enum, choices, type: t}` surfaces the base type alongside the `"enum"`
keyword, producing schemas consumers can validate against:

```elixir
Peri.to_json_schema({:enum, [1, 2, 3], type: :integer})
# => %{"type" => "integer", "enum" => [1, 2, 3]}
```

Decoding is symmetric: a JSON Schema with both `"type"` and `"enum"` round-trips
to a typed Peri enum. Numeric types retain their numeric constraints; `number`
accepts integers and floats, while `integer` accepts integers and only floats
with no fractional part. Numeric enum values are checked against both the type
and the enum members, treating numerically equal integer and float values as
the same JSON number. The decoded Peri enum may therefore contain both `5` and
`5.0`; encoding collapses numerically equivalent enum members.

## Decoding

```elixir
{:ok, schema} =
  Peri.from_json_schema(%{
    "type" => "object",
    "properties" => %{"name" => %{"type" => "string"}},
    "required" => ["name"]
  })

# schema => %{name: {:required, :string}}
```

`from_json_schema/1` runs `Peri.validate_schema/1` on the result, returning
`{:error, errors}` if the JSON Schema cannot be expressed as a valid Peri
schema.

## Lossy and unsupported conversions

- JSON Schema `oneOf` is decoded to Peri's first-success union. This has
  `anyOf`-like behavior, not JSON Schema's exactly-one-match behavior.
- `allOf` merges object properties. If two branches declare the same property
  with different Peri schemas, decoding returns
  `{:error, {:all_of_conflict, key, left, right}}`. Non-object/intersection
  branches that Peri cannot express also return an error. This is not a general
  JSON Schema intersection implementation.
- An object with `properties` and a schema-valued `additionalProperties` is
  represented with `{:schema, properties, {:additional_keys, value_type}}`,
  preserving and validating extra values. `additionalProperties: false` cannot
  be represented: Peri filters unknown keys rather than rejecting them. When
  `additionalProperties` is omitted, Peri's normal unknown-key filtering also
  differs from JSON Schema's permissive default.
- Recursive local `$ref` chains return `{:error, {:recursive_ref, name}}`.
  Resolving them would require a recursive schema model that Peri does not
  currently expose. No modules are generated at runtime.
- Draft 7 uses `definitions`; the encoder points refs at `#/definitions/...`
  and emits a matching `$defs` alias for compatibility with older Peri output.
  The decoder accepts both `definitions` and `$defs`.
- Peri `:float` encodes as JSON Schema `number`. Decoding `number` therefore
  accepts integer and floating-point values, and cannot recover the narrower
  original Peri `:float` type.
