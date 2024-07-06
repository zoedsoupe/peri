# Peri

Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema. It provides a powerful and flexible way to define and validate schemas for your data, ensuring data integrity and consistency throughout your application. Peri supports a variety of types and validation rules, and it can generate sample data based on your schemas.

## Features

- **Schema Definition**: Define schemas using a concise and expressive DSL.
- **Nested Schemas**: Support for deeply nested and complex schemas.
- **Custom Validation**: Implement custom validation functions for specific requirements.
- **Error Handling**: Detailed error messages with path information for easy debugging.
- **Data Generation**: Generate sample data based on your schemas using `StreamData`.

## Installation

Add this line to your `mix.exs`:
```elixir
defp deps do
  [
    {:peri, "~> 0.2"}
  ]
end
```

## Available Types

- `:any` - Allows any data type.
- `:atom` - Validates that the field is an atom.
- `:string` - Validates that the field is a binary (string).
  - `{:regex, regex}` - Validates that the string field matches a given `regex`
  - `{:eq, val}` - Validates that the string field is equal to `val`
  - `{:min, min}` - Validates that the string field has at least the `min` length
  - `{:max, max}` - Validates that the string field has at maximum the `max` length
- `:integer` - Validates that the field is an integer.
  - `{:eq, val}` - Validates taht the integer field is equal to `val`
  - `{:neq, val}` - Validates taht the integer field is not equal to `val`
  - `{:lt, val}` - Validates taht the integer field is lesss than `val`
  - `{:lte, val}` - Validates taht the integer field is less than or equal to `val`
  - `{:gt, val}` - Validates taht the integer field is greater than `val`
  - `{:gte, val}` - Validates taht the integer field is greater than or equal to `val`
  - `{:range, {min, max}}` - Validates taht the integer field is inside the range of `min` to `max` (inclusive)
- `:float` - Validates that the field is a float.
- `:boolean` - Validates that the field is a boolean.
- `:map` - Validates that the field is a map.
- `{:required, type}` - Marks the field as required and validates it according to the specified type.
- `{:enum, choices}` - Validates that the field is one of the specified choices.
- `{:list, type}` - Validates that the field is a list of elements of the specified type.
- `{:tuple, types}` - Validates that the field is a tuple with elements of the specified types.
- `{type, {:default, default}}` - Provides a default value if the field is missing or `nil`.
- `{type, {:transform, mapper}}` - Transforms the field value using the specified mapper function.
- `{:either, {type1, type2}}` - Validates that the field is either of the two specified types.
- `{:oneof, types}` - Validates that the field is one of the specified types.
- `{:custom, callback}` - Validates that the field passes the custom validation function.
- `{:custom, {mod, fun}}` - Validates that the field passes the custom validation function.
- `{:custom, {mod, fun, args}}` - Validates that the field passes the custom validation function.
- `{:dependent, field, condition, type}` - Validates the field based on the value of another field.
- `{:dependent, condition}` - Validates the field based on the value of multiple data values.
- `{:cond, condition, type, else_type}` - Conditional validation based on a condition function.

## Defining Schemas

### Using the Macro

You can define schemas using the `defschema` macro, which provides a concise syntax for defining and validating schemas.

```elixir
defmodule MySchemas do
  import Peri

  defschema :user, %{
    name: :string,
    age: {:integer, {:transform, & &1 * 2}},
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
```

### Without the Macro

You can also define schemas directly without using the macro:

```elixir
schema = %{
  name: :string,
  age: {:integer, {:transform, & &1 * 2}},
  email: {:required, :string}
}

Peri.validate(schema, %{name: "John", age: 30, email: "john@example.com"})
```

## Composable and Reusable Schemas

Schemas can be composed and reused to build complex data structures.

```elixir
defmodule MySchemas do
  import Peri

  defschema :address, %{
    street: :string,
    city: :string
  }

  defschema :user, %{
    name: :string,
    age: :integer,
    email: {:required, :string},
    address: get_schema(:address)
  }
end
```

## Custom Validation Functions

Implement custom validation functions to handle specific validation logic.

The spec of the custom validation function is:
```elixir
@spec validation(term) :: :ok | {:error, template :: String.t(), context :: map | keyword}
```

Where `template` is a template string with the notation of `%{value}` where `value` is the name of the variable to be injected on the template. And `context` is a map or keyword list where the key is the name of the variable that will be injected into the template and the value is the value of this injected variable. Let's see an example:

```elixir
defmodule MySchemas do
  import Peri

  defschema :user, %{
    name: :string,
    age: {:custom, &validate_age/1}
  }

  defp validate_age(age) when age >= 0 and age <= 120, do: :ok
  defp validate_age(age), do: {:error, "invalid age, received: %{age}", [age: age]}
end
```

## Error Handling with Peri.Error

Peri provides detailed error messages to help identify validation issues. Errors include path information to pinpoint the exact location of the error in the data structure.

```elixir
case Peri.validate(schema, data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

## Data Generation

Peri can generate sample data based on your schemas using `StreamData`.

For this feature to work, ensures that you application depends on [stream_data](https://hexdocs.pm/stream_data).

```elixir
schema = %{
  name: :string,
  age: {:integer, {:gte, 18}},
  active: :boolean
}

sample_data = Peri.generate(schema)
Enum.take(sample_data, 10) # Generates 10 samples of the schema
```

## Perfect for Raw Data Structures

Peri excels in validating raw data structures, such as tuples, strings, lists, and integers, with extensive validation options. This makes it ideal for use cases where you need to enforce strict data integrity rules on a wide variety of data types. Here's how Peri can help you handle these data structures:

### Tuples

Tuples can be validated for their structure and content, ensuring each element meets specific criteria.

```elixir
defmodule MySchemas do
  import Peri

  defschema :coordinates, {:tuple, [:float, :float]}
end

data = {12.34, 56.78}
Peri.validate(get_schema(:coordinates), data)
# => {:ok, {12.34, 56.78}}

invalid_data = {12.34, "not a float"}
Peri.validate(get_schema(:coordinates), invalid_data)
# => {:error, [%Peri.Error{message: "expected type of :float received \"not a float\" value"}]}
```

### Strings

Strings can be validated for length, equality, and matching regular expressions.

```elixir
defmodule MySchemas do
  import Peri

  defschema :username, {:string, {:regex, ~r/^[a-zA-Z0-9_]+$/}}
end

valid_data = %{username: "valid_user"}
Peri.validate(get_schema(:username), valid_data)
# => {:ok, %{username: "valid_user"}}

invalid_data = %{username: "invalid user"}
Peri.validate(get_schema(:username), invalid_data)
# => {:error, [%Peri.Error{message: "should match the ~r/^[a-zA-Z0-9_]+$/ pattern"}]}
```

### Lists

Lists can be validated to ensure all elements are of a specific type and meet certain criteria.

```elixir
defmodule MySchemas do
  import Peri

  defschema :tags, {:list, :string}
end

valid_data = %{tags: ["elixir", "programming"]}
Peri.validate(get_schema(:tags), valid_data)
# => {:ok, %{tags: ["elixir", "programming"]}}

invalid_data = %{tags: ["elixir", 42]}
Peri.validate(get_schema(:tags), invalid_data)
# => {:error, [%Peri.Error{message: "expected type of :string received 42 value"}]}
```

### Integers

Integers can be validated for equality, inequality, and range constraints.

```elixir
defmodule MySchemas do
  import Peri

  defschema :age, {:integer, {:range, {18, 65}}}
end

valid_data = %{age: 30}
Peri.validate(get_schema(:age), valid_data)
# => {:ok, %{age: 30}}

invalid_data = %{age: 17}
Peri.validate(get_schema(:age), invalid_data)
# => {:error, [%Peri.Error{message: "should be in the range of 18..65 (inclusive)"}]}
```

### Comprehensive Validation Options

Peri's robust validation capabilities make it suitable for various data types and validation needs:

- **Equality and Inequality**: Validate that values match or do not match specific criteria.
- **Ranges**: Ensure numerical values fall within specified bounds.
- **Regular Expressions**: Enforce patterns on string data.
- **Custom Validation**: Implement complex rules through custom functions.

By supporting these raw data structures and providing detailed error handling, Peri ensures that your data remains consistent and adheres to the defined rules, making it an excellent choice for applications requiring strict data validation.

## Comparison with other data validation and mapping libraries

### Peri vs. Norm

**Norm** is another Elixir library for schema and data validation. While it shares some similarities with Peri, there are distinct differences:

- **Focus**: Norm focuses on defining specifications and generating tests, offering a more comprehensive approach to data specifications, while Peri focuses on schema validation and transformations.
- **Validation**: Peri provides a more extensive set of built-in validations for strings, numbers, and custom types, whereas Norm allows for more generic and composable specifications.

### Peri vs. Drops

**Drops** is another Elixir library designed for validating and casting data. Key differences include:

- **Schema Definition**: Drops uses a different syntax and approach for defining schemas. Peri provides a more familiar and flexible schema definition approach, not relying on macros.
- **Validation Capabilities**: Peri offers more advanced validation features, such as default values, transformations, and custom validations.
- **Error Handling**: Both libraries provide detailed error handling, but Peri's `Peri.Error` struct offers more context and customization options for error messages.

### Peri vs. Ecto Schemaless Changesets

**Ecto** is a powerful data mapping and query generator for Elixir, and it offers schemaless changesets for validating data without defining database schemas.

- **Flexibility**: Peri offers more flexibility in defining schemas for various data structures, such as tuples, nested maps, and lists, along with detailed validation options.
- **Composable Validations**: Peri allows for more composable and reusable schemas, making it ideal for scenarios where data structures are complex and nested.

### Peri vs. Ecto Embedded Changesets

Ecto embedded changesets are used for validating and casting nested structures within Ecto schemas.

- **Nested Structures**: Both Peri and Ecto handle nested structures well. However, Peri provides more granular control over validation rules for different types of nested data.
- **Usage Context**: Ecto embedded changesets are tightly integrated with Ecto schemas and structs, whereas Peri can be used independently of any kind of data structure or type, making it more versatile for various use cases.
- **Custom Validations**: Peri's custom validation functions and integration with `StreamData` for data generation provide additional capabilities not available in Ecto.

### Summary

While all these libraries offer data validation capabilities, Peri stands out with its flexibility, comprehensive validation options, and integration with StreamData for data generation. Whether you're dealing with raw data structures, need advanced validation features, or want to generate test data, Peri provides a robust and versatile solution tailored to meet these needs.

## Why the Name "Peri"?

The name "Peri" is derived from the Greek word "περί" (pronounced "peri"), which means "around" or "about." This name was chosen to reflect the library's primary purpose: to provide comprehensive and flexible schema validation for data structures in Elixir. Just as "peri" suggests encompassing or surrounding something, Peri aims to cover all aspects of data validation, ensuring that data conforms to specified rules and constraints.

The choice of the name "Peri" also hints at the library's ability to handle a wide variety of data types and structures, much like how the term "around" can denote versatility and inclusiveness. Whether it's validating nested maps, complex tuples, or strings with specific patterns, Peri is designed to be a robust tool that can adapt to various validation needs in Elixir programming.
