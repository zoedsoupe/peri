# Ecto Integration

Convert Peri schemas to Ecto schemaless changesets for data validation.

## Basic Usage

```elixir
defmodule UserValidator do
  import Peri

  defschema :user, %{
    name: {:required, :string},
    age: {:integer, {:gte, 18}},
    email: {:required, {:string, {:regex, ~r/@/}}},
    role: {:enum, [:admin, :user]}
  }

  def validate_user(attrs) do
    # Convert Peri schema to Ecto changeset
    Peri.to_changeset!(get_schema(:user), attrs)
  end
end

# Usage
attrs = %{"name" => "John", "age" => 25, "email" => "john@example.com"}
changeset = UserValidator.validate_user(attrs)
```

## Type Mapping

Peri types are automatically mapped to appropriate Ecto types:

| Peri Type          | Ecto Type         | Notes                     |
| ------------------ | ----------------- | ------------------------- |
| `:string`          | `:string`         | Direct mapping            |
| `:integer`         | `:integer`        | Direct mapping            |
| `:float`           | `:float`          | Direct mapping            |
| `:boolean`         | `:boolean`        | Direct mapping            |
| `:date`            | `:date`           | Direct mapping            |
| `:datetime`        | `:utc_datetime`   | UTC datetime              |
| `:naive_datetime`  | `:naive_datetime` | Direct mapping            |
| `{:enum, choices}` | Peri validation   | Checks the original choice values |
| `{:enum, choices, type: type}` | Peri validation after primitive Ecto casting | Typed enum |
| `{:list, type}`    | `{:array, type}`  | Array of specified type   |
| `{:list, type, opts}` | Array plus changeset validations | `min`, `max`, and `unique` |
| `:any`             | Custom type       | Allows any value          |
| `:atom`            | Custom type       | Validates atoms           |
| `{:tuple, types}`  | Custom type       | Validates tuple structure |

## Constraint Mapping

Supported string and numeric constraints are converted to Ecto validations:

```elixir
# Peri schema
%{
  name: {:string, {:min, 2}},
  age: {:integer, {:range, {18, 65}}},
  email: {:string, {:regex, ~r/@/}}
}

# Equivalent Ecto validations applied
changeset
|> validate_length(:name, min: 2)
|> validate_number(:age, greater_than_or_equal_to: 18, less_than_or_equal_to: 65)
|> validate_format(:email, ~r/@/)
```

Multiple constraints on one field are applied independently. Numeric
`multiple_of` uses a changeset validation because Ecto's number validator does
not provide a divisibility option. Required fields with error options preserve
their required/type behavior, but custom Peri error messages are not used by
the changeset adapter.

List-level `min`, `max`, and `unique` options are validated after Ecto casts the
array:

```elixir
%{tags: {:list, :string, [min: 1, max: 5, unique: true]}}
```

## Support and limitations

- Primitive types use Ecto casting. Tuple, map, either, oneof, literal, custom,
  conditional, dependent, and transform forms use adapter validations where
  supported by the parser.
- Peri coercion directives run through `Peri.validate/2` at the changeset
  boundary. Failed coercions add a normal field error; successful coercions
  store their result as a changeset change.
- Typed enums use the declared primitive type's Ecto cast where available,
  then check choice membership. Enum `error:` and `gen:` metadata is ignored.
- Required `error:` and schema/list constraint `error:` or `gen:` metadata do
  not alter Ecto errors or runtime casting.
- Ecto changesets do not execute Peri's full validation pipeline. Callback
  context and exact `Peri.Error` structures are not transferred. Map key/value
  constraints are limited to the adapter's supported primitive checks.
- Recursive refs are represented as opaque maps in the changeset. Use
  `Peri.validate/2` when ref resolution or the full Peri error path is needed.

## Nested Validation

```elixir
defmodule ProfileValidator do
  import Peri

  defschema :address, %{
    street: {:required, :string},
    city: {:required, :string},
    zip: {:string, {:regex, ~r/^\d{5}$/}}
  }

  defschema :user, %{
    name: {:required, :string},
    address: {:required, get_schema(:address)},
    tags: {:list, :string}
  }

  def validate_user(attrs) do
    changeset = Peri.to_changeset!(get_schema(:user), attrs)
    # Nested validation happens automatically
    case changeset.valid? do
      true -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      false -> {:error, changeset}
    end
  end
end

# Usage with nested data
attrs = %{
  "name" => "John",
  "address" => %{
    "street" => "123 Main St",
    "city" => "Anytown",
    "zip" => "12345"
  },
  "tags" => ["developer", "elixir"]
}

case ProfileValidator.validate_user(attrs) do
  {:ok, validated_data} -> IO.puts("Valid!")
  {:error, changeset} -> IO.inspect(changeset.errors)
end
```

## Custom Types

Peri provides custom Ecto types for advanced validation:

```elixir
# Available custom types
Peri.Ecto.Type.Any      # Accepts any value
Peri.Ecto.Type.Atom     # Validates atoms
Peri.Ecto.Type.Tuple    # Validates tuples
Peri.Ecto.Type.Either   # Union types
Peri.Ecto.Type.OneOf    # Multiple choice types
```

## Error Handling

Adapter validation failures are reported as ordinary Ecto changeset errors.
Error templates and nested `Peri.Error` structures are not preserved:

```elixir
attrs = %{"name" => "", "age" => 15}
changeset = Peri.to_changeset!(schema, attrs)

# Access errors like normal Ecto changeset
changeset.errors
# [
#   name: {"can't be blank", [validation: :required]},
#   age: {"must be greater than or equal to %{number}",
#         [validation: :number, kind: :greater_than_or_equal_to, number: 18]}
# ]

# Check if valid
if changeset.valid? do
  data = Ecto.Changeset.apply_changes(changeset)
  {:ok, data}
else
  {:error, changeset}
end
```

## Working with Phoenix

Perfect for Phoenix controller validation:

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  import Peri

  defschema :user_params, %{
    name: {:required, :string},
    email: {:required, {:string, {:regex, ~r/@/}}},
    age: {:integer, {:gte, 18}}
  }

  def create(conn, params) do
    changeset = Peri.to_changeset!(get_schema(:user_params), params)

    if changeset.valid? do
      user_data = Ecto.Changeset.apply_changes(changeset)
      # Process valid data...
      json(conn, %{success: true, user: user_data})
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: translate_errors(changeset)})
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
```

## Benefits

- **Familiar API**: Uses standard Ecto changeset interface
- **Rich Validation**: Use the documented subset of Peri validations supported by the adapter
- **Error Consistency**: Standard Ecto error format
- **Phoenix Ready**: Works seamlessly with Phoenix forms and APIs
- **Composable**: Combine with other Ecto changeset operations
