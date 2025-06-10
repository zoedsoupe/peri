# Types Reference

Peri provides a comprehensive set of built-in types for schema validation.

## Basic Types

| Type | Description | Example |
|------|-------------|---------|
| `:any` | Accepts any value | `:any` |
| `:atom` | Validates atoms | `:atom` |
| `:string` | Validates binary strings | `:string` |
| `:integer` | Validates integers | `:integer` |
| `:float` | Validates floats | `:float` |
| `:boolean` | Validates booleans | `:boolean` |
| `:map` | Validates maps (no content validation) | `:map` |
| `:pid` | Validates process identifiers | `:pid` |

## Time Types

| Type | Description | Example |
|------|-------------|---------|
| `:date` | Validates `%Date{}` | `:date` |
| `:time` | Validates `%Time{}` | `:time` |
| `:datetime` | Validates `%DateTime{}` | `:datetime` |
| `:naive_datetime` | Validates `%NaiveDateTime{}` | `:naive_datetime` |
| `:duration` | Validates `%Duration{}` | `:duration` |

## Collection Types

| Type | Description | Example |
|------|-------------|---------|
| `{:list, type}` | List of elements of specified type | `{:list, :string}` |
| `{:map, type}` | Map with values of specified type | `{:map, :integer}` |
| `{:map, key_type, value_type}` | Map with typed keys and values | `{:map, :atom, :string}` |
| `{:tuple, types}` | Tuple with elements of specified types | `{:tuple, [:float, :float]}` |

## String Constraints

| Type | Description | Example |
|------|-------------|---------|
| `{:string, {:regex, regex}}` | String matching regex pattern | `{:string, {:regex, ~r/^\w+$/}}` |
| `{:string, {:eq, value}}` | String equal to value | `{:string, {:eq, "exact"}}` |
| `{:string, {:min, length}}` | String with minimum length | `{:string, {:min, 3}}` |
| `{:string, {:max, length}}` | String with maximum length | `{:string, {:max, 50}}` |

## Integer Constraints

| Type | Description | Example |
|------|-------------|---------|
| `{:integer, {:eq, value}}` | Integer equal to value | `{:integer, {:eq, 42}}` |
| `{:integer, {:neq, value}}` | Integer not equal to value | `{:integer, {:neq, 0}}` |
| `{:integer, {:gt, value}}` | Integer greater than value | `{:integer, {:gt, 0}}` |
| `{:integer, {:gte, value}}` | Integer greater than or equal | `{:integer, {:gte, 18}}` |
| `{:integer, {:lt, value}}` | Integer less than value | `{:integer, {:lt, 100}}` |
| `{:integer, {:lte, value}}` | Integer less than or equal | `{:integer, {:lte, 99}}` |
| `{:integer, {:range, {min, max}}}` | Integer within range (inclusive) | `{:integer, {:range, {18, 65}}}` |

## Choice Types

| Type | Description | Example |
|------|-------------|---------|
| `{:enum, choices}` | Value must be one of choices | `{:enum, [:admin, :user, :guest]}` |
| `{:literal, value}` | Value must exactly match | `{:literal, :active}` |
| `{:either, {type1, type2}}` | Value matches either type | `{:either, {:string, :integer}}` |
| `{:oneof, types}` | Value matches one of types | `{:oneof, [:string, :integer, :atom]}` |

## Modifiers

| Type | Description | Example |
|------|-------------|---------|
| `{:required, type}` | Field is required | `{:required, :string}` |
| `{type, {:default, value}}` | Default value if missing | `{:string, {:default, "unknown"}}` |
| `{type, {:default, fun}}` | Default from function | `{:integer, {:default, &System.system_time/0}}` |
| `{type, {:default, {m, f}}}` | Default from MFA | `{:string, {:default, {MyMod, :get_default}}}` |
| `{type, {:transform, fun}}` | Transform value | `{:string, {:transform, &String.upcase/1}}` |
| `{type, {:transform, {m, f}}}` | Transform with MFA | `{:string, {:transform, {MyMod, :clean}}}` |

## Custom Validation

| Type | Description | Example |
|------|-------------|---------|
| `{:custom, callback}` | Custom validation function | `{:custom, &validate_email/1}` |
| `{:custom, {mod, fun}}` | Custom validation MFA | `{:custom, {MyMod, :validate}}` |
| `{:custom, {mod, fun, args}}` | Custom validation with args | `{:custom, {MyMod, :validate, []}}` |

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