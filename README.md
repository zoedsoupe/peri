# Peri - Schema Validation Library for Elixir

## General Description

Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema. It allows developers to define schemas for validating various data structures, supporting nested schemas, optional fields, and custom validation types. Peri aims to provide an intuitive and flexible way to ensure data integrity in Elixir applications.

## Features

- Simple and intuitive syntax for defining schemas.
- Validation of data structures against schemas.
- Support for nested, composable, and recursive schemas.
- Optional and required fields.
- Comprehensive error handling with detailed messages.
- Flexible validation types, including custom and conditional validations.

## Installation

To use Peri in your project, add it to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:peri, "~> 0.2.3"}
  ]
end
```

Then, run `mix deps.get` to fetch the dependencies.

## Usage

### Available Types

Peri supports a variety of types to ensure your data is validated accurately. Below is a table summarizing the available types and their descriptions:

| Type                                      | Description                                                                                     |
|-------------------------------------------|-------------------------------------------------------------------------------------------------|
| `:string`                                 | Validates that the field is a binary (string).                                                  |
| `:integer`                                | Validates that the field is an integer.                                                         |
| `:float`                                  | Validates that the field is a float.                                                            |
| `:boolean`                                | Validates that the field is a boolean.                                                          |
| `:atom`                                   | Validates that the field is an atom.                                                            |
| `:any`                                    | Allows any datatype.                                                                            |
| `{:required, type}`                       | Marks the field as required and validates it according to the specified type.                   |
| `:map`                                    | Validates that the field is a map without checking nested schema.                               |
| `{:either, {type_1, type_2}}`             | Validates that the field is either of `type_1` or `type_2`.                                     |
| `{:oneof, types}`                         | Validates that the field is at least one of the provided types.                                 |
| `{:list, type}`                           | Validates that the field is a list where elements belong to a determined type.                  |
| `{:tuple, types}`                         | Validates that the field is a tuple with a determined size, and each element has its own type validation. |
| `{:custom, anonymous_fun_arity_1}`        | Validates that the field passes the callback. The function needs to return either `:ok` or `{:error, template, info}` where `template` is an EEx string and `info` is a keyword list or map. |
| `{:custom, {MyModule, :my_validation}}`   | Same as `{custom, anonymous_fun_arity_1}` but you pass a remote module and a function name as an atom. |
| `{:custom, {MyModule, :my_validation, [arg1, arg2]}}` | Same as `{:custom, {MyModule, :my_validation}}` but you can pass extra arguments to your validation function. Note that the value of the field is always the first argument. |
| `{:cond, condition, true_type, else_type}` | Conditionally validates a field based on the result of a condition function.                    |
| `{:dependent, field, condition, type}`    | Validates a field based on the value of another field.                                          |

These types provide flexibility and control over how data is validated, enabling robust and precise schema definitions.

### Defining and Validating Schemas

Schemas can be defined using the `defschema` macro. By default, all fields in the schema are optional unless specified as `{:required, type}`.

#### Example

```elixir
defmodule MySchemas do
  import Peri

  defschema :user, %{
    name: :string,
    age: :integer,
    email: {:required, :string},
    address: %{
      street: :string,
      city: :string
    },
    tags: {:list, :string},
    role: {:enum, [:admin, :user, :guest]},
    geolocation: {:tuple, [:float, :float]},
    rating: {:custom, &validate_rating/1}
  }

  defp validate_rating(n) when n < 10, do: :ok
  defp validate_rating(_), do: {:error, "invalid rating", []}
end

user_data = %{
  name: "John",
  age: 30,
  email: "john@example.com",
  address: %{street: "123 Main St", city: "Somewhere"},
  tags: ["science", "funky"],
  role: :admin,
  geolocation: {12.2, 34.2},
  rating: 9
}

case MySchemas.user(user_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

### `defschema` Macro General Explanation

The `defschema` macro allows you to define a schema with a given name and schema definition. This macro injects functions that can validate data against the defined schema. 

### Defining Schemas Without Macro

You can also define schemas without using the `defschema` macro by directly passing the schema definition to the `Peri.validate/2` function.

```elixir
defmodule MySchemas do
  @raw_user_schema %{age: :integer, name: :string}

  def create_user(data) do
    with {:ok, data} <- Peri.validate(@raw_user_schema, data) do
      # rest of the function ...
    end
  end
end
```

### Dynamic Schemas

Dynamic schemas can be generated based on runtime conditions.

```elixir
defmodule MySchemas do
  import Peri

  def generate_schema(is_admin) do
    if is_admin do
      %{
        role: {:required, :string},
        permissions: {:list, :string}
      }
    else
      %{
        role: {:required, :string}
      }
    end
  end

  def validate_user(data, is_admin) do
    schema = generate_schema(is_admin)
    Peri.validate(schema, data)
  end
end

data = %{role: "admin", permissions: ["read", "write"]}
case MySchemas.validate_user(data, true) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

### Nested and Composable Schemas

Peri supports nested schemas, allowing for validation of complex data structures.

```elixir
defmodule MySchemas do
  import Peri

  defschema :address, %{
    street: :string,
    city: :string
  }

  defschema :user, %{
    name: :string,
    email: {:required, :string},
    address: {:custom, &address/1}
  }
end

data = %{name: "John", email: "john@example.com", address: %{street: "123 Main St", city: "Somewhere"}}
case MySchemas.user(data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

### Recursive Schemas

Recursive schemas allow you to define schemas that reference themselves, enabling the validation of nested and hierarchical data structures.

```elixir
defmodule MySchemas do
  import Peri

  defschema :category, %{
    id: :integer,
    name: :string,
    subcategories: {:list, {:custom, &category/1}}
  }

  category_data = %{
    id: 1,
    name: "Electronics",
    subcategories: [
      %{id: 2, name: "Computers", subcategories: []},
      %{id: 3, name: "Phones", subcategories: [%{id: 4, name: "Smartphones", subcategories: []}]}
    ]
  }

  case MySchemas.category(category_data) do
    {:ok, valid_data} -> IO.puts("Category is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
end
```

### Schemas on Raw Data Structures

Peri allows you to define schemas for various data structures, including lists, tuples, keyword lists, and primitive types.

#### Lists

```elixir
defmodule MySchemas do
  import Peri

  defschema :string_list, {:list, :string}

  data = ["hello", "world"]
  case MySchemas.string_list(data) do
    {:ok, valid_data} -> IO.puts("Data is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
end
```

#### Tuples

```elixir
defmodule MySchemas do
  import Peri

  defschema :coordinates, {:tuple, [:float, :float]}

  data = {12.34, 56.78}
  case MySchemas.coordinates(data) do
    {:ok, valid_data} -> IO.puts("Data is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
end
```

#### Keyword Lists

```elixir
defmodule MySchemas do
  import Peri

  defschema :settings, [{:key, :string}, {:value, :any}]

  data = [key: "theme", value: "dark"]
  case MySchemas.settings(data) do
    {:ok, valid_data} -> IO.puts("Data is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
end
```

### Error Handling

Peri provides detailed error messages that can be easily inspected and transformed. Each error includes a message, content, path, key, and nested errors for detailed information about nested validation errors.

```elixir
defmodule MySchemas do
  import Peri

  defschema :user, %{
    name: :string,
    age: {:required, :integer}
  }

  data = %{name: "Jane"}
  case MySchemas.user(data) do
    {:ok, valid_data} -> IO.puts("Data is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
end
```

### InvalidSchema Exception

Peri raises an `InvalidSchema` exception when an invalid schema is encountered. This exception contains a list of `Peri.Error` structs, providing a readable message overview of the validation errors.

## Comparison with Ecto Schemaless Changesets and Embedded Schemas

### Peri

- **Purpose**: Designed specifically for schema validation. Focuses on validating raw maps against defined schemas.
- **Flexibility**: Allows easy validation of nested structures, optional fields, and dynamic schemas.
- **Simplicity**: The syntax for defining schemas is straightforward and intuitive.
- **Use Case**: Ideal for validating data structures in contexts where you don't need the full power of a database ORM.

### Ecto Schemaless Changesets

- **Purpose**: Provides mechanisms for validating and casting data without persisting it to a database.
- **Complexity**: More complex due to its integration with Ecto and the need to handle changesets.
- **Schema Definitions**: Uses Ecto changesets and embedded schemas, which are typically tied to database schemas.
- **Use Case**: Ideal for applications that require validation and casting of data, even when it’s not being persisted to a database.

### Summary

- Use **Peri** if you need a lightweight, flexible library for validating raw maps and nested data structures without the overhead of database interactions.
- Use **Ecto Schemaless Changesets** if you need to validate and cast data in an Ecto-based application, leveraging the full power of Ecto’s changeset functionality.

