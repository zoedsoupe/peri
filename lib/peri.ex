defmodule Peri do
  @moduledoc """
  Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema.
  It provides a flexible and powerful way to define and validate data structures using schemas. 
  The library supports nested schemas, optional fields, custom validation functions, and various type constraints.

  ## Key Features

  - **Simple and Nested Schemas**: Define schemas that can handle complex, nested data structures.
  - **Optional and Required Fields**: Specify fields as optional or required with type constraints.
  - **Custom Validation Functions**: Use custom functions to validate fields.
  - **Comprehensive Error Handling**: Provides detailed error messages for validation failures.
  - **Type Constraints**: Supports various types including enums, lists, tuples, and more.

  ## Usage

  To define a schema, use the `defschema` macro. By default, all fields in the schema are optional unless specified otherwise.

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
  ```

  You can then use the schema to validate data:

  ```elixir
  user_data = %{
    name: "John", age: 30, email: "john@example.com",
    address: %{street: "123 Main St", city: "Somewhere"},
    tags: ["science", "funky"], role: :admin,
    geolocation: {12.2, 34.2}, rating: 9
  }

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
  - `:atom` - Validates that the field is an atom.
  - `:any` - Allows any datatype.
  - `{:required, type}` - Marks the field as required and validates it according to the specified type.
  - `:map` - Validates that the field is a map.
  - `{:either, {type_1, type_2}}` - Validates that the field is either of `type_1` or `type_2`.
  - `{:oneof, types}` - Validates that the field is at least one of the provided types.
  - `{:list, type}` - Validates that the field is a list with elements of the specified type.
  - `{:tuple, types}` - Validates that the field is a tuple with the specified types in sequence.
  - `{:custom, anonymous_fun_arity_1}` - Validates that the field passes the callback function.
  - `{:custom, {MyModule, :my_validation}}` - Validates using a function from a specific module.
  - `{:custom, {MyModule, :my_validation, [arg1, arg2]}}` - Same as above but allows extra arguments.
  -	`{:cond, condition, true_type, else_type}` - Validates the field based on a condition.
  -	`{:dependent, field, condition, type}` - Validates the field based on another field’s value.
  -	`{type, {:default, default}}` - Sets a default value for a field if it is nil.

  ## Error Handling

  Peri provides detailed error messages that include the path to the invalid data, the expected and actual values, and custom error messages for custom validations.

  ## Functions

  - `validate/2` - Validates data against a schema.
  - `conforms?/2` - Checks if data conforms to a schema.
  - `validate_schema/1` - Validates the schema definition.

  ## Example

  ```elixir
  defmodule MySchemas do
    import Peri

    defschema :user, %{
      name: :string,
      age: :integer,
      email: {:required, :string}
    }
  end

  user_data = %{name: "John", age: 30, email: "john@example.com"}
  case MySchemas.user(user_data) do
    {:ok, valid_data} -> IO.puts("Data is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
  ```
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
    bang = :"#{name}!"

    quote do
      def get_schema(unquote(name)) do
        unquote(schema)
      end

      def unquote(name)(data) do
        with {:ok, schema} <- Peri.validate_schema(unquote(schema)) do
          Peri.validate(schema, data)
        end
      end

      def unquote(bang)(data) do
        with {:ok, valid_schema} <- Peri.validate_schema(unquote(schema)),
             {:ok, valid_data} <- Peri.validate(valid_schema, data) do
          valid_data
        else
          {:error, errors} -> raise Peri.InvalidSchema, errors
        end
      end
    end
  end

  defguardp is_enumerable(data) when is_map(data) or is_list(data)

  def conforms?(schema, data) do
    case validate(schema, data) do
      {:ok, _} -> true
      {:error, _errors} -> false
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
  def validate(schema, data) when is_enumerable(schema) and is_enumerable(data) do
    data = filter_data(schema, data)
    state = Peri.Parser.new(data)

    case traverse_schema(schema, state) do
      %Peri.Parser{errors: [], data: result} -> {:ok, result}
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  def validate(schema, data) do
    case validate_field(data, schema, data) do
      :ok ->
        {:ok, data}

      {:ok, result} ->
        {:ok, result}

      {:error, reason, info} ->
        {:error, Peri.Error.new_single(reason, info)}
    end
  end

  defp filter_data(schema, data) do
    acc = if is_map(schema), do: %{}, else: []

    Enum.reduce(schema, acc, fn {key, type}, acc ->
      string_key = to_string(key)
      value = get_enumerable_value(data, key)
      original_key = if enumerable_has_key?(data, key), do: key, else: string_key

      cond do
        is_enumerable(data) and not enumerable_has_key?(data, key) ->
          acc

        is_enumerable(value) and is_enumerable(type) ->
          nested_filtered_value = filter_data(type, value)
          put_in(acc[original_key], nested_filtered_value)

        true ->
          put_in(acc[original_key], value)
      end
    end)
    |> then(fn
      %{} = data -> data
      data when is_list(data) -> Enum.reverse(data)
    end)
  end

  defp enumerable_has_key?(data, key) when is_map(data) do
    Map.has_key?(data, key) or Map.has_key?(data, Atom.to_string(key))
  end

  defp enumerable_has_key?(data, key) when is_list(data) do
    Keyword.has_key?(data, key)
  end

  @doc false
  defp traverse_schema(schema, %Peri.Parser{} = state, path \\ []) do
    Enum.reduce(schema, state, fn {key, type}, parser ->
      value = get_enumerable_value(parser.data, key)

      case validate_field(value, type, parser) do
        :ok ->
          parser

        {:ok, value} ->
          Peri.Parser.update_data(parser, key, value)

        {:error, [%Peri.Error{} = nested_err | _]} ->
          nested_err
          |> Peri.Error.update_error_paths(path ++ [key])
          |> then(&Peri.Error.new_parent(path, key, [&1]))
          |> then(&Peri.Parser.add_error(parser, &1))

        {:error, reason, info} ->
          err = Peri.Error.new_child(path, key, reason, info)
          Peri.Parser.add_error(parser, err)
      end
    end)
  end

  defp get_enumerable_value(enum, key) do
    case Access.get(enum, key) do
      nil when is_map(enum) -> Map.get(enum, Atom.to_string(key))
      val -> val
    end
  end

  @doc false
  defp validate_field(nil, nil, _data), do: :ok
  defp validate_field(_, :any, _data), do: :ok
  defp validate_field(val, :atom, _data) when is_atom(val), do: :ok
  defp validate_field(val, :map, _data) when is_map(val), do: :ok
  defp validate_field(val, :string, _data) when is_binary(val), do: :ok
  defp validate_field(val, :integer, _data) when is_integer(val), do: :ok
  defp validate_field(val, :float, _data) when is_float(val), do: :ok
  defp validate_field(val, :boolean, _data) when is_boolean(val), do: :ok
  defp validate_field(val, :list, _data) when is_list(val), do: :ok
  defp validate_field(nil, {:required, _}, _data), do: {:error, "is required", []}

  defp validate_field(_val, {:required, {type, {:default, _}}}, _data) do
    template =
      "cannot set default value of default@example.com for required field of type %{type}"

    {:ok, template, [type: type]}
  end

  defp validate_field(m, {:required, :map}, _data) when m == %{},
    do: {:error, "cannot be empty", []}

  defp validate_field(m, {:required, s}, _data) when m == %{} and is_map(s),
    do: {:error, "cannot be empty", []}

  defp validate_field([], {:required, {:list, _}}, _data), do: {:error, "cannot be empty", []}
  defp validate_field(val, {:required, type}, data), do: validate_field(val, type, data)

  defp validate_field(val, {type, {:default, default}}, data) do
    val = if is_nil(val), do: default, else: val

    with :ok <- validate_field(val, type, data) do
      {:ok, val}
    end
  end

  defp validate_field(nil, _, _data), do: :ok

  defp validate_field(val, {:custom, callback}, _data) when is_function(callback, 1) do
    callback.(val)
  end

  defp validate_field(val, {:custom, {mod, fun}}, _data)
       when is_atom(mod) and is_atom(fun) do
    apply(mod, fun, [val])
  end

  defp validate_field(val, {:custom, {mod, fun, args}}, _data)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [val | args])
  end

  defp validate_field(val, {:cond, condition, true_type, else_type}, data) do
    if condition.(data) do
      validate_field(val, true_type, data)
    else
      validate_field(val, else_type, data)
    end
  end

  defp validate_field(val, {:dependent, field, condition, type}, data) do
    dependent_val = get_enumerable_value(data, field)

    with :ok <- condition.(val, dependent_val) do
      validate_field(val, type, data)
    end
  end

  defp validate_field(val, {:either, {type_1, type_2}}, data) do
    with {:error, _, _} <- validate_field(val, type_1, data),
         {:error, _, _} <- validate_field(val, type_2, data) do
      info = [first_type: type_1, second_type: type_2, actual: inspect(val)]
      template = "expected either %{first_type} or %{second_type}, got: %{actual}"
      {:error, template, info}
    end
  end

  defp validate_field(val, {:oneof, types}, data) do
    types
    |> Enum.reduce_while(:error, fn type, :error ->
      case validate_field(val, type, data) do
        :ok -> {:halt, :ok}
        {:error, _reason, _info} -> {:cont, :error}
      end
    end)
    |> then(fn
      :ok ->
        :ok

      :error ->
        expected = Enum.map_join(types, " or ", &to_string/1)
        info = [oneof: expected, actual: inspect(val)]
        template = "expected one of %{oneof}, got: %{actual}"

        {:error, template, info}
    end)
  end

  defp validate_field(source, {:tuple, types}, data) when is_tuple(source) do
    if tuple_size(source) == length(types) do
      Enum.with_index(types)
      |> Enum.reduce_while({:ok, []}, fn {type, index}, {:ok, vals} ->
        case validate_field(elem(source, index), type, data) do
          :ok ->
            {:cont, {:ok, vals}}

          {:ok, val} ->
            {:cont, {:ok, [val | vals]}}

          {:error, reason, nested_info} ->
            info = [index: index] ++ nested_info
            {:halt, {:error, "tuple element %{index}: #{reason}", info}}
        end
      end)
      |> then(fn
        :ok -> :ok
        {:ok, []} -> :ok
        {:ok, vals} -> {:ok, List.to_tuple(Enum.reverse(vals))}
        {:error, reason, info} -> {:error, reason, info}
      end)
    else
      info = [length: length(types), actual: length(Tuple.to_list(source))]
      template = "expected tuple of size %{length} received tuple with %{actual} length"
      {:error, template, info}
    end
  end

  defp validate_field(val, {:enum, choices}, _data) do
    if to_string(val) in Enum.map(choices, &to_string/1) do
      :ok
    else
      info = [choices: inspect(choices, pretty: true), actual: inspect(val)]
      template = "expected one of %{choices} received %{actual}"
      {:error, template, info}
    end
  end

  defp validate_field(data, {:list, type}, source) when is_list(data) do
    Enum.reduce_while(data, {:ok, nil}, fn el, {:ok, val} ->
      case validate_field(el, type, source) do
        :ok -> {:cont, {:ok, val}}
        {:ok, val} -> {:cont, {:ok, val}}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, reason, info} -> {:halt, {:error, reason, info}}
      end
    end)
    |> then(fn
      {:ok, _} -> :ok
      err -> err
    end)
  end

  defp validate_field(data, schema, _data) when is_enumerable(data) do
    case traverse_schema(schema, Peri.Parser.new(data)) do
      %Peri.Parser{errors: []} = parser -> {:ok, parser.data}
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  defp validate_field(val, type, _data) do
    info = [expected: type, actual: inspect(val, pretty: true)]
    {:error, "expected type of %{expected} received %{actual} value", info}
  end

  @doc """
  Validates a schema definition to ensure it adheres to the expected structure and types.

  This function can handle both simple and complex schema definitions, including nested schemas, custom validation functions, and various type constraints.

  ## Parameters

    - `schema` - The schema definition to be validated. It can be a map or a keyword list representing the schema.

  ## Returns

    - `{:ok, schema}` - If the schema is valid, returns the original schema.
    - `{:error, errors}` - If the schema is invalid, returns an error tuple with detailed error information.

  ## Examples

    Validating a simple schema:
    
    ```elixir
    schema = %{
      name: :string,
      age: :integer,
      email: {:required, :string}
    }
    assert {:ok, ^schema} = validate_schema(schema)
    ```

    Validating a nested schema:

    ```elixir
    schema = %{
      user: %{
        name: :string,
        profile: %{
          age: {:required, :integer},
          email: {:required, :string}
        }
      }
    }
    assert {:ok, ^schema} = validate_schema(schema)
    ```

    Handling invalid schema definition:

    ```elixir
    schema = %{
      name: :str,
      age: :integer,
      email: {:required, :string}
    }
    assert {:error, _errors} = validate_schema(schema)
    ```
  """
  def validate_schema(schema) when is_enumerable(schema) do
    case traverse_definition(schema, Peri.Parser.new(schema)) do
      %Peri.Parser{errors: [], data: data} -> {:ok, data}
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  def validate_schema(schema) do
    case validate_type(schema, Peri.Parser.new(schema)) do
      :ok ->
        {:ok, schema}

      {:error, reason, info} ->
        {:error, Peri.Error.new_single(reason, info)}
    end
  end

  defp traverse_definition(schema, state) when is_enumerable(schema) do
    Enum.reduce(schema, state, fn {key, type}, %{path: path} = parser ->
      case validate_type(type, parser) do
        :ok ->
          parser

        {:error, [%Peri.Error{} = nested_err | _]} ->
          nested_err
          |> Peri.Error.update_error_paths(path ++ [key])
          |> then(&Peri.Error.new_parent(path, key, [&1]))
          |> then(&Peri.Parser.add_error(parser, &1))

        {:error, reason, info} ->
          err = Peri.Error.new_child(path, key, reason, [{:schema, schema} | info])
          Peri.Parser.add_error(parser, err)
      end
    end)
  end

  defp validate_type(nil, _parser), do: :ok
  defp validate_type(:any, _parser), do: :ok
  defp validate_type(:atom, _parser), do: :ok
  defp validate_type(:integer, _parser), do: :ok
  defp validate_type(:map, _parser), do: :ok
  defp validate_type(:float, _parser), do: :ok
  defp validate_type(:boolean, _parser), do: :ok
  defp validate_type(:string, _parser), do: :ok
  defp validate_type({type, {:default, _val}}, p), do: validate_type(type, p)
  defp validate_type({:enum, choices}, _) when is_list(choices), do: :ok

  defp validate_type({:required, {type, {:default, val}}}, _) do
    template = "cannot set default value of %{value} for required field of type %{type}"
    {:error, template, [value: val, type: type]}
  end

  defp validate_type({:required, type}, p), do: validate_type(type, p)
  defp validate_type({:list, type}, p), do: validate_type(type, p)
  defp validate_type({:custom, cb}, _) when is_function(cb, 1), do: :ok
  defp validate_type({:custom, {mod, fun}}, _) when is_atom(mod) and is_atom(fun), do: :ok

  defp validate_type({:custom, {mod, fun, args}}, _)
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: :ok

  defp validate_type({:cond, cb, type, else_type}, p) when is_function(cb, 1) do
    with :ok <- validate_type(type, p) do
      validate_type(else_type, p)
    end
  end

  defp validate_type({:dependent, _, cb, type}, p) when is_function(cb, 1) do
    validate_type(type, p)
  end

  defp validate_type({:tuple, types}, p) do
    Enum.reduce_while(types, :ok, fn type, :ok ->
      case validate_type(type, p) do
        :ok -> {:cont, :ok}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, template, info} -> {:halt, {:error, template, info}}
      end
    end)
  end

  defp validate_type({:either, {type_1, type_2}}, p) do
    with :ok <- validate_type(type_1, p) do
      validate_type(type_2, p)
    end
  end

  defp validate_type({:oneof, types}, p) do
    Enum.reduce_while(types, :ok, fn type, :ok ->
      case validate_type(type, p) do
        :ok -> {:cont, :ok}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, template, info} -> {:halt, {:error, template, info}}
      end
    end)
  end

  defp validate_type(schema, p) when is_enumerable(schema) do
    case traverse_definition(schema, p) do
      %Peri.Parser{errors: []} -> :ok
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  defp validate_type(invalid, _p) do
    invalid = inspect(invalid, pretty: true)
    {:error, "invalid schema definition: %{invalid}", invalid: invalid}
  end
end
