defmodule Peri do
  @moduledoc """
  Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema.
  It focuses on validating raw maps and supports nested schemas and optional fields.

  ## Usage

  To define a schema, use the `defschema` macro. By default, all fields in the schema are optional unless specified as `{:required, type}`.

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
      }
    }
  end
  ```

  You can then use the schema to validate data:

  ```elixir
  user_data = %{name: "John", age: 30, email: "john@example.com", address: %{street: "123 Main St", city: "Somewhere"}}
  case MySchemas.user(user_data) do
    {:ok, valid_data} -> IO.puts("Data is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
  ```

  ## Available Types

  - `:string` - Validates that the field is a binary (string).
  - `:integer` - Validates that the field is an integer.
  - `:float` - Validates that the field is a float.
  - `:boolean` - Validates that the field is a boolean.
  - `{:required, type}` - Marks the field as required and validates it according to the specified type.
  - `:map` - Validates that the field is a map without checking nested schema.
  """

  @doc """
  Defines a schema with a given name and schema definition.

  ## Examples

      defmodule MySchemas do
        import Peri

        defschema :user, %{
          name: :string,
          age: :integer,
          email: {:required, :string}
        }
      end

      user_data = %{name: "John", age: 30, email: "john@example.com"}
      MySchemas.user(user_data)
      # => {:ok, %{name: "John", age: 30, email: "john@example.com"}}

      invalid_data = %{name: "John", age: 30}
      MySchemas.user(invalid_data)
      # => {:error, [email: "is required"]}
  """
  defmacro defschema(name, schema) do
    quote do
      def unquote(name)(data) do
        Peri.validate(unquote(schema), data)
      end
    end
  end

  @doc """
  Validates a given data map against a schema.

  Returns `{:ok, data}` if the data is valid according to the schema, or `{:error, errors}` if there are validation errors.

  ## Parameters

    - schema: The schema definition map.
    - data: The data map to be validated.

  ## Examples

      schema = %{
        name: :string,
        age: :integer,
        email: {:required, :string}
      }

      data = %{name: "John", age: 30, email: "john@example.com"}
      Peri.validate(schema, data)
      # => {:ok, %{name: "John", age: 30, email: "john@example.com"}}

      invalid_data = %{name: "John", age: 30}
      Peri.validate(schema, invalid_data)
      # => {:error, [email: "is required"]}
  """
  def validate(schema, data) when is_map(schema) and is_map(data) do
    case traverse_schema(schema, data) do
      [] -> {:ok, data}
      errors -> {:error, errors}
    end
  end

  @doc false
  defp traverse_schema(schema, data) do
    Enum.reduce(schema, [], fn {key, type}, errors ->
      value = Map.get(data, key)

      case validate_field(value, type) do
        :ok -> errors
        {:error, reason} -> [{key, reason} | errors]
      end
    end)
  end

  @doc false
  defp validate_field(val, :map) when is_map(val), do: :ok
  defp validate_field(val, :string) when is_binary(val), do: :ok
  defp validate_field(val, :integer) when is_integer(val), do: :ok
  defp validate_field(val, :float) when is_float(val), do: :ok
  defp validate_field(val, :boolean) when is_boolean(val), do: :ok
  defp validate_field(nil, {:required, _}), do: {:error, "is required"}
  defp validate_field(val, {:required, type}), do: validate_field(val, type)
  defp validate_field(nil, _), do: :ok

  defp validate_field(data, schema) when is_map(data) do
    case traverse_schema(schema, data) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_field(val, type), do: {:error, "expected #{type} received #{val}"}
end
