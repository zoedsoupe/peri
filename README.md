# Peri

Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema. It provides a powerful and flexible way to define and validate schemas for your data, ensuring data integrity and consistency throughout your application.

## Features

- **Schema Definition**: Define schemas using a concise and expressive DSL
- **Nested Validation**: Support for deeply nested and complex schemas
- **Custom Validation**: Implement custom validation functions for specific requirements
- **Data Generation**: Generate sample data based on your schemas using StreamData
- **Ecto Integration**: Convert Peri schemas to Ecto changesets for seamless database integration
- **Validation Modes**: Choose between strict (default) and permissive validation modes

## Installation

Add this line to your `mix.exs`:
```elixir
defp deps do
  [
    {:peri, "~> 0.5.1"} # x-release-please-version
  ]
end
```

## Quick Start

```elixir
defmodule MyApp.Schemas do
  import Peri

  defschema :user, %{
    name: {:required, :string},
    age: {:integer, {:gte, 18}},
    email: {:required, :string},
    role: {:enum, [:admin, :user, :guest]}
  }
end

# Validate data
data = %{name: "John", age: 25, email: "john@example.com", role: :user}
MyApp.Schemas.user(data)
# => {:ok, validated_data}

# Validate with permissive mode (preserves extra fields)
data_with_extra = %{name: "John", age: 25, email: "john@example.com", role: :user, extra: "field"}
Peri.validate(MyApp.Schemas.get_schema(:user), data_with_extra, mode: :permissive)
# => {:ok, %{name: "John", age: 25, email: "john@example.com", role: :user, extra: "field"}}
```

## Documentation

For detailed documentation on types, validation patterns, and integrations, see:

- **[Types Reference](pages/types.md)** - All available types and constraints
- **[Validation Patterns](pages/validation.md)** - Conditional, dependent, and custom validation  
- **[Ecto Integration](pages/ecto.md)** - Converting schemas to Ecto changesets
- **[Data Generation](pages/generation.md)** - Generate sample data with StreamData

## Why the Name "Peri"?

The name "Peri" is derived from the Greek word "περί" (pronounced "peri"), which means "around" or "about." This name was chosen to reflect the library's primary purpose: to provide comprehensive and flexible schema validation for data structures in Elixir. Just as "peri" suggests encompassing or surrounding something, Peri aims to cover all aspects of data validation, ensuring that data conforms to specified rules and constraints.

The choice of the name "Peri" also hints at the library's ability to handle a wide variety of data types and structures, much like how the term "around" can denote versatility and inclusiveness. Whether it's validating nested maps, complex tuples, or strings with specific patterns, Peri is designed to be a robust tool that can adapt to various validation needs in Elixir programming.
