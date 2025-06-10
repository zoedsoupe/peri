# Data Generation

Generate sample data based on your Peri schemas using StreamData.

## Setup

Add StreamData to your dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:peri, "~> 0.4"},
    {:stream_data, "~> 1.0", only: [:test, :dev]}
  ]
end
```

## Basic Usage

```elixir
defmodule UserSchema do
  import Peri

  defschema :user, %{
    name: :string,
    age: {:integer, {:gte, 18}},
    active: :boolean
  }
end

# Generate sample data
sample_data = Peri.generate(UserSchema.get_schema(:user))
Enum.take(sample_data, 3)
# [
#   %{name: "abc", age: 23, active: true},
#   %{name: "xyz", age: 45, active: false},
#   %{name: "def", age: 67, active: true}
# ]
```

## Constraint-Aware Generation

Generators respect Peri constraints:

```elixir
schema = %{
  username: {:string, {:regex, ~r/^[a-z]+$/}},
  score: {:integer, {:range, {0, 100}}},
  role: {:enum, [:admin, :user, :guest]},
  tags: {:list, :string}
}

# Generated data will match constraints
samples = Peri.generate(schema) |> Enum.take(5)
# All usernames will be lowercase letters only
# All scores will be 0-100
# All roles will be from the enum
```

## Property-Based Testing

Perfect for property-based testing with ExUnit:

```elixir
defmodule UserTest do
  use ExUnit.Case
  use ExUnitProperties
  import Peri

  defschema :user, %{
    name: {:required, :string},
    age: {:integer, {:gte, 0, :lte, 120}},
    email: {:string, {:regex, ~r/@/}}
  }

  property "user validation always succeeds for generated data" do
    check all user_data <- Peri.generate(get_schema(:user)) do
      assert {:ok, _} = Peri.validate(get_schema(:user), user_data)
    end
  end

  property "age is always within bounds" do
    check all %{age: age} <- Peri.generate(get_schema(:user)) do
      assert age >= 0 and age <= 120
    end
  end
end
```

## Complex Data Structures

Generate nested and complex data:

```elixir
defmodule ComplexSchema do
  import Peri

  defschema :address, %{
    street: :string,
    city: :string,
    zip: {:string, {:regex, ~r/^\d{5}$/}}
  }

  defschema :person, %{
    name: {:required, :string},
    addresses: {:list, get_schema(:address)},
    preferences: {:map, :string, :boolean},
    coordinates: {:tuple, [:float, :float]}
  }
end

# Generates fully nested structures
sample = Peri.generate(ComplexSchema.get_schema(:person)) |> Enum.take(1) |> hd()
# %{
#   name: "John",
#   addresses: [
#     %{street: "123 Main", city: "Boston", zip: "02101"},
#     %{street: "456 Oak", city: "Salem", zip: "01970"}
#   ],
#   preferences: %{"dark_mode" => true, "notifications" => false},
#   coordinates: {42.3601, -71.0589}
# }
```

## Custom Generators

For `:custom` types, provide your own generators:

```elixir
defmodule CustomSchema do
  import Peri

  defschema :product, %{
    id: {:custom, &validate_uuid/1},
    price: {:custom, &validate_price/1}
  }

  defp validate_uuid(uuid) when is_binary(uuid) do
    # UUID validation logic
    :ok
  end

  defp validate_price(price) when is_number(price) and price > 0, do: :ok
  defp validate_price(_), do: {:error, "invalid price", []}
end

# Note: Custom generators need to be implemented separately
# This is a limitation - custom types require manual generator setup
```

## Seeding Development Data

Use for development database seeding:

```elixir
defmodule MyApp.Seeds do
  import Peri

  defschema :user_seed, %{
    name: {:string, {:min, 3}},
    email: {:string, {:regex, ~r/.+@.+\..+/}},
    role: {:enum, [:admin, :user]},
    active: {:boolean, {:default, true}}
  }

  def seed_users(count \\ 50) do
    Peri.generate(get_schema(:user_seed))
    |> Enum.take(count)
    |> Enum.each(fn user_data ->
      MyApp.Users.create_user(user_data)
    end)
  end
end

# Run in seeds.exs or IEx
MyApp.Seeds.seed_users(100)
```

## API Testing

Generate test data for API endpoints:

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase
  use ExUnitProperties
  import Peri

  defschema :user_request, %{
    name: {:required, :string},
    email: {:required, {:string, {:regex, ~r/@/}}},
    age: {:integer, {:gte, 18}}
  }

  property "POST /users accepts valid user data" do
    check all user_params <- Peri.generate(get_schema(:user_request)) do
      conn = post(build_conn(), "/users", user_params)
      assert json_response(conn, 201)
    end
  end
end
```

## Limitations

- **Custom Types**: Custom validation types need manual generator implementation
- **Performance**: Large data generation may be slow for complex nested structures
- **Dependencies**: Requires StreamData dependency for generation features

## Best Practices

- Use generation primarily for testing and development seeding
- Keep generated data size reasonable for performance
- Combine with ExUnitProperties for comprehensive property-based testing
- Use constraints to ensure realistic data generation