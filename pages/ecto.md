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

| Peri Type | Ecto Type | Notes |
|-----------|-----------|--------|
| `:string` | `:string` | Direct mapping |
| `:integer` | `:integer` | Direct mapping |
| `:float` | `:float` | Direct mapping |
| `:boolean` | `:boolean` | Direct mapping |
| `:date` | `:date` | Direct mapping |
| `:datetime` | `:utc_datetime` | UTC datetime |
| `:naive_datetime` | `:naive_datetime` | Direct mapping |
| `{:enum, choices}` | Custom validation | Validates against choices |
| `{:list, type}` | `{:array, type}` | Array of specified type |
| `:any` | Custom type | Allows any value |
| `:atom` | Custom type | Validates atoms |
| `{:tuple, types}` | Custom type | Validates tuple structure |

## Constraint Mapping

Peri constraints are converted to Ecto validations:

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

Peri validation errors are automatically converted to Ecto changeset errors:

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
- **Rich Validation**: Access to all Peri's validation features
- **Error Consistency**: Standard Ecto error format
- **Phoenix Ready**: Works seamlessly with Phoenix forms and APIs
- **Composable**: Combine with other Ecto changeset operations