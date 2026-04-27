# Types Reference

Peri provides a comprehensive set of built-in types for schema validation.

## Basic Types

| Type       | Description                            | Example    |
| ---------- | -------------------------------------- | ---------- |
| `:any`     | Accepts any value                      | `:any`     |
| `:atom`    | Validates atoms                        | `:atom`    |
| `:string`  | Validates binary strings               | `:string`  |
| `:integer` | Validates integers                     | `:integer` |
| `:float`   | Validates floats                       | `:float`   |
| `:boolean` | Validates booleans                     | `:boolean` |
| `:map`     | Validates maps (no content validation) | `:map`     |
| `:pid`     | Validates process identifiers          | `:pid`     |

## Time Types

| Type              | Description                  | Example           |
| ----------------- | ---------------------------- | ----------------- |
| `:date`           | Validates `%Date{}`          | `:date`           |
| `:time`           | Validates `%Time{}`          | `:time`           |
| `:datetime`       | Validates `%DateTime{}`      | `:datetime`       |
| `:naive_datetime` | Validates `%NaiveDateTime{}` | `:naive_datetime` |
| `:duration`       | Validates `%Duration{}`      | `:duration`       |

## Collection Types

| Type                                              | Description                                                               | Example                                                     |
| ------------------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `{:list, type}`                                   | List of elements of specified type                                        | `{:list, :string}`                                          |
| `{:map, type}`                                    | Map with values of specified type                                         | `{:map, :integer}`                                          |
| `{:map, key_type, value_type}`                    | Map with typed keys and values                                            | `{:map, :atom, :string}`                                    |
| `{:tuple, types}`                                 | Tuple with elements of specified types                                    | `{:tuple, [:float, :float]}`                                |
| `{:schema, map_schema, {:additional_keys, type}}` | Map with some strictly defined fields, with extras under a different type | `{:schema, %{main: :string}, {:additional_keys, :integer}}` |

## String Constraints

| Type                         | Description                   | Example                                                    |
| ---------------------------- | ----------------------------- | ---------------------------------------------------------- |
| `{:string, {:regex, regex}}` | String matching regex pattern | `{:string, {:regex, ~r/^\w+$/}}`                           |
| `{:string, {:eq, value}}`    | String equal to value         | `{:string, {:eq, "exact"}}`                                |
| `{:string, {:min, length}}`  | String with minimum length    | `{:string, {:min, 3}}`                                     |
| `{:string, {:max, length}}`  | String with maximum length    | `{:string, {:max, 50}}`                                    |
| `{:string, [...options]}`    | String with multiple options  | `{:string, [min: 8, max: 64, regex: ~r/^[a-zA-Z0-9-]+$/]}` |

## Integer Constraints

| Type                               | Description                      | Example                          |
| ---------------------------------- | -------------------------------- | -------------------------------- |
| `{:integer, {:eq, value}}`         | Integer equal to value           | `{:integer, {:eq, 42}}`          |
| `{:integer, {:neq, value}}`        | Integer not equal to value       | `{:integer, {:neq, 0}}`          |
| `{:integer, {:gt, value}}`         | Integer greater than value       | `{:integer, {:gt, 0}}`           |
| `{:integer, {:gte, value}}`        | Integer greater than or equal    | `{:integer, {:gte, 18}}`         |
| `{:integer, {:lt, value}}`         | Integer less than value          | `{:integer, {:lt, 100}}`         |
| `{:integer, {:lte, value}}`        | Integer less than or equal       | `{:integer, {:lte, 99}}`         |
| `{:integer, {:range, {min, max}}}` | Integer within range (inclusive) | `{:integer, {:range, {18, 65}}}` |
| `{:integer, [...options]}`         | Integer with multiple options    | `{:integer, [gt: 12, lte: 96]}`  |

## Float Constraints

| Type                             | Description                    | Example                             |
| -------------------------------- | ------------------------------ | ----------------------------------- |
| `{:float, {:eq, value}}`         | Float equal to value           | `{:float, {:eq, 3.1415}}`           |
| `{:float, {:neq, value}}`        | Float not equal to value       | `{:float, {:neq, 1.9}}`             |
| `{:float, {:gt, value}}`         | Float greater than value       | `{:float, {:gt, 1.0}}`              |
| `{:float, {:gte, value}}`        | Float greater than or equal    | `{:float, {:gte, 9.12}}`            |
| `{:float, {:lt, value}}`         | Float less than value          | `{:float, {:lt, 10.0}}`             |
| `{:float, {:lte, value}}`        | Float less than or equal       | `{:float, {:lte, 99.999}}`          |
| `{:float, {:range, {min, max}}}` | Float within range (inclusive) | `{:float, {:range, {8.3, 15.3}}}`   |
| `{:float, [...options]}`         | Float with multiple options    | `{:float, [gt: 1.52, lte: 29.123]}` |

## Choice Types

| Type                        | Description                  | Example                                |
| --------------------------- | ---------------------------- | -------------------------------------- |
| `{:enum, choices}`          | Value must be one of choices | `{:enum, [:admin, :user, :guest]}`     |
| `{:literal, value}`         | Value must exactly match     | `{:literal, :active}`                  |
| `{:either, {type1, type2}}` | Value matches either type    | `{:either, {:string, :integer}}`       |
| `{:oneof, types}`           | Value matches one of types   | `{:oneof, [:string, :integer, :atom]}` |

## Modifiers

| Type                           | Description                             | Example                                                                |
| ------------------------------ | --------------------------------------- | ---------------------------------------------------------------------- |
| `{:required, type}`            | Field is required                       | `{:required, :string}`                                                 |
| `{type, {:default, value}}`    | Default value if missing                | `{:string, {:default, "unknown"}}`                                     |
| `{type, {:default, fun}}`      | Default from function                   | `{:integer, {:default, &System.system_time/0}}`                        |
| `{type, {:default, {m, f}}}`   | Default from MFA                        | `{:string, {:default, {MyMod, :get_default}}}`                         |
| `{type, {:transform, fun}}`    | Transform value                         | `{:string, {:transform, &String.upcase/1}}`                            |
| `{type, {:transform, {m, f}}}` | Transform with MFA                      | `{:string, {:transform, {MyMod, :clean}}}`                             |
| `{:meta, type, opts}`          | Attach metadata, passthrough validation | `{:meta, {:required, :string}, doc: "Login email", example: "a@b.io"}` |
| `{:ref, atom}`                 | Reference a schema in the same module   | `{:list, {:ref, :tree}}`                                                |
| `{:ref, {Mod, atom}}`          | Reference a schema in another module    | `{:ref, {OtherMod, :node}}`                                             |
| `{:multi, field, branches}`    | Tagged union dispatched on `field`      | `{:multi, :type, %{"circle" => %{r: :float}, "rect" => %{w: :float}}}`  |

## Schema Metadata

The `{:meta, type, opts}` wrapper attaches documentation/tooling info to a field
without affecting validation. Blessed keys: `:doc`, `:title`, `:description`,
`:example`, `:deprecated`. User keys are preserved opaquely.

`defschema` accepts schema-level meta opts (any non-validation key), exposed via
the generated `__schema_meta__/1`:

```elixir
defmodule MySchemas do
  import Peri

  defschema :user, %{
    email: {:meta, {:required, :string}, doc: "Login email", example: "a@b.io"},
    age: {:meta, {:integer, gte: 0}, description: "Years"}
  }, title: "User", description: "Account holder"
end

MySchemas.__schema_meta__(:user)
# => [title: "User", description: "Account holder"]
```

## Tagged Unions (`:multi`)

`{:multi, dispatch_field, branches}` is sugar for a discriminated union: the
value is dispatched on `dispatch_field`, then validated against the
matching branch schema. Errors localize to the chosen branch, so failures
read as `shape.radius: invalid` rather than "didn't match any of N
schemas".

```elixir
%{
  shape: {:multi, :type, %{
    "circle" => %{type: {:required, :string}, radius: {:required, :float}},
    "rect"   => %{type: {:required, :string}, w: {:required, :float}, h: {:required, :float}}
  }}
}
```

A missing dispatch field, or a value not present in `branches`, surfaces
as a clear validation error listing the known tags. JSON Schema export
emits `oneOf` plus a `discriminator` annotation; data generation samples
a branch and merges the dispatch tag into the generated value.

For untagged "any of these types" semantics, use `{:oneof, types}` instead.

## Custom Validation

| Type                          | Description                 | Example                             |
| ----------------------------- | --------------------------- | ----------------------------------- |
| `{:custom, callback}`         | Custom validation function  | `{:custom, &validate_email/1}`      |
| `{:custom, {mod, fun}}`       | Custom validation MFA       | `{:custom, {MyMod, :validate}}`     |
| `{:custom, {mod, fun, args}}` | Custom validation with args | `{:custom, {MyMod, :validate, []}}` |

## Custom Error Messages

Override the default error template for any field using the `error:` opt in its
options list. Accepted forms: a static string, or an MFA `{mod, fun, args}` that
receives the `%Peri.Error{}` prepended to `args` and returns a string.

| Form                                            | Description                                | Example                                         |
| ----------------------------------------------- | ------------------------------------------ | ----------------------------------------------- |
| `{type, [..., error: msg]}`                     | Static replacement message                 | `{:integer, gte: 18, error: "must be adult"}`   |
| `{:required, type, [error: msg]}`               | Static message on a required field         | `{:required, :string, [error: "needed"]}`       |
| `{:required, type, [error: {mod, fun, args}]}`  | MFA receives `%Peri.Error{}` and returns string | `{:required, :string, [error: {Msgs, :email, []}]}` |

```elixir
defmodule MyApp.Schemas do
  import Peri

  defmodule Msgs do
    def email_msg(%Peri.Error{content: ctx}), do: "email is invalid (#{inspect(ctx)})"
  end

  defschema :user, %{
    age:   {:integer, gte: 18, error: "must be adult"},
    email: {:required, :string, [error: {Msgs, :email_msg, []}]}
  }
end
```

For i18n, post-process the error list with `Peri.Error.traverse_errors/2`,
which walks nested errors and replaces each leaf message with the callback's
return value:

```elixir
{:error, errors} = MyApp.Schemas.user(%{age: 10})

Peri.Error.traverse_errors(errors, fn err ->
  Gettext.dgettext(MyAppWeb.Gettext, "errors", err.message, err.content || %{})
end)
```

The MFA / static override fires first; `traverse_errors/2` runs over whatever
message remains (overridden or default). No hard dependency on Gettext —
the callback is opaque.

## Examples

### Simple User Schema

```elixir
%{
  name: {:required, :string},
  age: {:integer, {:gte, 0}},
  email: {:required, {:string, {:regex, ~r/@/}}},
  role: {:enum, [:admin, :user]}
}
```

### Complex Nested Schema

```elixir
%{
  user: %{
    profile: {:required, %{
      name: {:required, :string},
      bio: {:string, {:max, 500}}
    }},
    preferences: {:map, :string, :boolean},
    tags: {:list, :string}
  }
}
```
