# Validation Patterns

Advanced validation patterns for dynamic and context-aware schemas.

## Validation Modes

Peri supports two validation modes to control how extra fields are handled:

### Strict Mode (Default)

By default, Peri operates in strict mode, which filters out any fields not defined in the schema:

```elixir
schema = %{
  name: :string,
  age: :integer
}

data = %{name: "John", age: 30, extra: "field"}

{:ok, result} = Peri.validate(schema, data)
# result => %{name: "John", age: 30}
```

### Permissive Mode

Permissive mode preserves all fields from the input data, even those not defined in the schema:

```elixir
{:ok, result} = Peri.validate(schema, data, mode: :permissive)
# result => %{name: "John", age: 30, extra: "field"}
```

### Using Permissive Mode with defschema

You can define schemas that always use permissive mode:

```elixir
defmodule MySchemas do
  import Peri

  # Strict mode (default)
  defschema :user_strict, %{
    name: :string,
    email: {:required, :string}
  }

  # Permissive mode
  defschema :user_permissive, %{
    name: :string,
    email: {:required, :string}
  }, mode: :permissive
end

data = %{name: "John", email: "john@example.com", role: "admin"}

# Strict mode filters out 'role'
{:ok, strict} = MySchemas.user_strict(data)
# strict => %{name: "John", email: "john@example.com"}

# Permissive mode keeps 'role'
{:ok, permissive} = MySchemas.user_permissive(data)  
# permissive => %{name: "John", email: "john@example.com", role: "admin"}
```

### Use Cases for Permissive Mode

Permissive mode is useful when:
- Building API gateways that need to forward extra fields
- Implementing progressive validation in layers
- Working with evolving data structures where new fields may be added
- Creating middleware that validates known fields but passes through metadata

**Note**: Fields not defined in the schema are not validated, they are simply passed through unchanged.

## Conditional Validation

Use `:cond` to validate fields based on runtime conditions.

```elixir
defmodule UserSchema do
  import Peri

  defschema :registration, %{
    name: {:required, :string},
    is_premium: {:required, :boolean},
    # Only require payment info if premium
    payment_info: {:cond, & &1.is_premium, {:required, :string}, nil}
  }
end
```

## Dependent Validation

### Single Field Dependency

Validate a field based on another field's value:

```elixir
defmodule AuthSchema do
  import Peri

  defschema :user, %{
    password: {:required, :string},
    password_confirmation: {:dependent, :password, &match_passwords/2, :string}
  }

  defp match_passwords(password, password), do: :ok
  defp match_passwords(_, _), do: {:error, "passwords must match", []}
end
```

### Multiple Field Dependencies

Complex validation based on multiple fields:

```elixir
defmodule ProfileSchema do
  import Peri

  defschema :user_profile, %{
    contact_type: {:required, {:enum, [:email, :phone, :both]}},
    email: {:string, {:regex, ~r/@/}},
    phone: :string,
    contact_info: {:dependent, &validate_contact/1}
  }

  defp validate_contact(%{data: %{contact_type: :email}}) do
    {:ok, {:required, %{email: {:required, :string}}}}
  end
  
  defp validate_contact(%{data: %{contact_type: :phone}}) do
    {:ok, {:required, %{phone: {:required, :string}}}}
  end
  
  defp validate_contact(%{data: %{contact_type: :both}}) do
    {:ok, {:required, %{
      email: {:required, :string},
      phone: {:required, :string}
    }}}
  end
end
```

## Custom Validation

### Simple Custom Validator

```elixir
defmodule ProductSchema do
  import Peri

  defschema :product, %{
    price: {:custom, &validate_price/1}
  }

  defp validate_price(price) when price > 0, do: :ok
  defp validate_price(price), do: {:error, "price must be positive, got %{price}", [price: price]}
end
```

### MFA Custom Validators

```elixir
defmodule OrderSchema do
  import Peri

  defschema :order, %{
    items: {:list, {:custom, {__MODULE__, :validate_item, [:in_stock]}}},
    total: {:custom, {Calculator, :validate_total}}
  }

  def validate_item(item, :in_stock) do
    if item.stock > 0 do
      :ok
    else
      {:error, "item %{name} is out of stock", [name: item.name]}
    end
  end
end
```

## Callback Arities

### 1-Arity Callbacks (Root Data)

Receives the entire root data structure:

```elixir
%{
  user_type: :premium,
  features: {:cond, fn data -> data.user_type == :premium end, 
             {:list, :string}, 
             {:literal, []}}
}
```

### 2-Arity Callbacks (Current + Root)

Receives current context and root data - useful for lists:

```elixir
defmodule ItemSchema do
  import Peri

  defschema :item, %{
    type: {:required, :string},
    # Validates based on current item's type, not parent data
    value: {:dependent, fn current, _root ->
      case current.type do
        "number" -> {:ok, :integer}
        "text" -> {:ok, :string}
        _ -> {:ok, :any}
      end
    end}
  }

  defschema :collection, %{
    items: {:list, get_schema(:item)}
  }
end

# Each item validates independently
data = %{
  items: [
    %{type: "number", value: 42},
    %{type: "text", value: "hello"}
  ]
}
```

## Schema Composition

### Reusable Schemas

```elixir
defmodule BaseSchemas do
  import Peri

  defschema :address, %{
    street: {:required, :string},
    city: {:required, :string},
    zip: {:string, {:regex, ~r/^\d{5}$/}}
  }

  defschema :person, %{
    name: {:required, :string},
    address: get_schema(:address)
  }

  defschema :company, %{
    name: {:required, :string},
    headquarters: get_schema(:address),
    employees: {:list, get_schema(:person)}
  }
end
```

### Schema Merging

```elixir
defmodule UserSchemas do
  import Peri

  defschema :base_user, %{
    name: {:required, :string},
    email: {:required, :string}
  }

  defschema :admin_user, Map.merge(get_schema(:base_user), %{
    permissions: {:required, {:list, :string}},
    last_login: :datetime
  })
end
```

## Error Context

Custom validators can provide detailed error context:

```elixir
defp validate_complex_rule(value) do
  case expensive_validation(value) do
    :ok -> :ok
    {:error, reason} -> 
      {:error, "validation failed: %{reason} for value %{value}", 
       [reason: reason, value: inspect(value)]}
  end
end
```