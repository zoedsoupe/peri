# Peri

Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema. It focuses on validating raw maps and supports nested schemas and optional fields. With Peri, you can define schemas and validate data structures in a concise and readable manner.

## Features

- Define schemas using a simple and intuitive syntax.
- Validate data structures against schemas.
- Support for nested schemas.
- Optional and required fields.

## Installation

To use Peri in your project, add it to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:peri, "~> 0.1.0"}
  ]
end
```

Then, run `mix deps.get` to fetch the dependencies.

## Usage

### Defining Schemas

To define a schema, use the `defschema` macro. By default, all fields in the schema are optional unless specified as `{:required, type}`.

```elixir
defmodule MySchemas do
  import Peri

  defschema :product, %{
    id: {:required, :integer},
    name: {:required, :string},
    price: :float,
    in_stock: :boolean
  }
end
```

### Validating Data

You can then use the schema to validate data:

```elixir
product_data = %{id: 1, name: "Laptop", price: 999.99, in_stock: true}
case MySchemas.product(product_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

### Available Types

Peri supports the following types for schema definitions:

  - `:string` - Validates that the field is a binary (string).
  - `:integer` - Validates that the field is an integer.
  - `:float` - Validates that the field is a float.
  - `:boolean` - Validates that the field is a boolean.
  - `{:required, type}` - Marks the field as required and validates it according to the specified type.
  - `:map` - Validates that the field is a map without checking nested schema.
  - `{:list, type}` - Validates that the field is a list where elements belongs to a determined type.
  - `{:tuple, types}` - Validates that the field is a tuple with determined size and each element have your own type validation (sequential).
  - `{custom, anonymous_fun_arity_1}` - Validates that the field passes on the callback, the function needs to return either `:ok` or `{:error, reason}` where `reason` should be a string.
  - `{:custom, {MyModule, :my_validation}}` - Same as `{custom, anonymous_fun_arity_1}` but you pass a remote module and a function name as atom.
  - `{:custom, {MyModule, :my_validation, [arg1, arg2]}}` - Same as `{:custom, {MyModule, :my_validation}}` but you can pass extra arguments to your validation function. Note that the value of the field is always the first argument.
  - Nested maps with schema defined

## Examples

### Simple Schema Validation

```elixir
defmodule MySchemas do
  import Peri

  defschema :order, %{
    order_id: {:required, :integer},
    customer_name: {:required, :string},
    total_amount: :float
  }
end

order_data = %{order_id: 123, customer_name: "Alice", total_amount: 59.99}
case MySchemas.order(order_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end

invalid_order_data = %{order_id: 123}
case MySchemas.order(invalid_order_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

### Nested Schema Validation

```elixir
defmodule MySchemas do
  import Peri

  defschema :user_profile, %{
    username: {:required, :string},
    email: {:required, :string},
    details: %{
      age: :integer,
      bio: :string
    }
  }
end

profile_data = %{
  username: "bob_smith",
  email: "bob@example.com",
  details: %{age: 30, bio: "Software developer"}
}

case MySchemas.user_profile(profile_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end

invalid_profile_data = %{
  username: "bob_smith",
  email: "bob@example.com",
  details: %{age: "thirty"}
}

case MySchemas.user_profile(invalid_profile_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

### Comparison: Peri vs. Ecto

While both Peri and Ecto provide mechanisms for working with schemas in Elixir, they serve different purposes and are used in different contexts.

#### Peri
- **Purpose**: Peri is designed specifically for schema validation. It focuses on validating raw maps against defined schemas.
- **Flexibility**: Peri allows for easy validation of nested structures and optional fields.
- **Simplicity**: The syntax for defining schemas in Peri is simple and intuitive, making it easy to use for straightforward validation tasks.
- **Use Case**: Ideal for validating data structures in contexts where you don't need the full power of a database ORM.

#### Ecto
- **Purpose**: Ecto is a comprehensive database wrapper and query generator for Elixir. It provides tools for defining schemas, querying databases, and managing changesets.
- **Complexity**: Ecto is more complex due to its broader feature set, which includes support for migrations, associations, and transactions.
- **Schema Definitions**: Ecto schemas are typically tied to database tables, with a focus on struct-based data manipulation.
- **Use Case**: Ideal for applications that require robust interaction with a database, including data validation, querying, and persistence.

#### Summary
- Use **Peri** if you need a lightweight, flexible library for validating raw maps and nested data structures without the overhead of database interactions.
- Use **Ecto** if you need a powerful tool for managing database schemas, querying, and data persistence, and if you require comprehensive features like associations, migrations, and transactions.

By understanding the different strengths and use cases of Peri and Ecto, you can choose the right tool for your specific needs, ensuring efficient and effective data handling in your Elixir applications.

## Why "Peri"?

The name "Peri" is derived from the prefix "peri-" which means "around" or "surrounding". This reflects the library's purpose of providing a protective layer around your data structures, ensuring they conform to specified schemas. Just as a perimeter protects and defines boundaries, Peri ensures that your data is validated and well-defined according to your schemas.

## Contributing

We welcome contributions to Peri! If you have suggestions for improvements or find bugs, please open an issue or submit a pull request on GitHub.

## License

Peri is released under the MIT License. See the LICENSE file for more details.

---

Peri makes it easy to define and validate data structures in Elixir, providing a powerful tool for ensuring data integrity in your applications. Start using Peri today and enjoy simple, reliable schema validation!
