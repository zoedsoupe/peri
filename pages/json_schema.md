# JSON Schema

Peri can convert schemas to and from JSON Schema (Draft 7) maps.

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
| `{:literal, v}`                             | `"const"`                             |
| `{:either, {a, b}}`, `{:oneof, ts}`         | `"oneOf"`                             |
| `{:required, t}`                            | adds key to parent `"required"`       |
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
