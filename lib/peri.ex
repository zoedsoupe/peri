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
  user_data = %{name: "John", age: 30, email: "john@example.com", address: %{street: "123 Main St", city: "Somewhere"}, tags: ["science", "funky"], role: :admin, geolocation: {12.2, 34.2}, rating: 9}
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
  - `:any` - Allow any datatype.
  - `{:required, type}` - Marks the field as required and validates it according to the specified type.
  - `:map` - Validates that the field is a map without checking nested schema.
  - `{:either, {type_1, type_2}}` - Validates that the field is either of `type_1` or `type_2`.
  - `{:oneof, types}` - Validates that the field is at least one of the provided types.
  - `{:list, type}` - Validates that the field is a list where elements belongs to a determined type.
  - `{:tuple, types}` - Validates that the field is a tuple with determined size and each element have your own type validation (sequential).
  - `{custom, anonymous_fun_arity_1}` - Validates that the field passes on the callback, the function needs to return either `:ok` or `{:error, reason}` where `reason` should be a string.
  - `{:custom, {MyModule, :my_validation}}` - Same as `{custom, anonymous_fun_arity_1}` but you pass a remote module and a function name as atom.
  - `{:custom, {MyModule, :my_validation, [arg1, arg2]}}` - Same as `{:custom, {MyModule, :my_validation}}` but you can pass extra arguments to your validation function. Note that the value of the field is always the first argument.
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

    case traverse_schema(schema, data) do
      {[], _path} -> {:ok, data}
      {errors, _path} -> {:error, errors}
    end
  end

  def validate(schema, data) do
    case validate_field(data, schema, data) do
      :ok ->
        {:ok, data}

      {:error, reason, info} ->
        msg = EEx.eval_string(reason, info)
        err = %Peri.Error{message: msg, content: info}

        {:error, err}
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
  defp traverse_schema(schema, data, path \\ []) do
    Enum.reduce(schema, {[], path}, fn {key, type}, {errors, path} ->
      value = get_enumerable_value(data, key)

      case validate_field(value, type, data) do
        :ok ->
          {errors, []}

        {:error, [%Peri.Error{} = nested_err | _]} ->
          current_path = path ++ [key]
          nested_error = update_error_paths(nested_err, current_path)
          err = %Peri.Error{path: current_path, key: key, errors: [nested_error]}
          {[err | errors], path}

        {:error, reason, info} ->
          msg = EEx.eval_string(reason, info)
          current_path = path ++ [key]
          err = %Peri.Error{path: current_path, message: msg, content: info, key: key}

          {[err | errors], path}
      end
    end)
  end

  defp get_enumerable_value(enum, key) do
    case Access.get(enum, key) do
      nil when is_map(enum) -> Map.get(enum, Atom.to_string(key))
      val -> val
    end
  end

  defp update_error_paths(%Peri.Error{path: path, errors: nil} = error, new_path) do
    %Peri.Error{error | path: new_path ++ path}
  end

  defp update_error_paths(%Peri.Error{path: path, errors: errors} = error, new_path) do
    updated_errors = Enum.map(errors, &update_error_paths(&1, new_path))
    %Peri.Error{error | path: new_path ++ path, errors: updated_errors}
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
  defp validate_field([], {:required, {:list, _}}, _data), do: {:error, "cannot be empty", []}
  defp validate_field(val, {:required, type}, data), do: validate_field(val, type, data)
  defp validate_field(nil, _, _data), do: :ok

  defp validate_field(val, {:custom, callback}, _data) when is_function(callback, 1) do
    case callback.(val) do
      :ok -> :ok
      {:ok, _} -> :ok
      err -> err
    end
  end

  defp validate_field(val, {:custom, {mod, fun}}, _data) do
    case apply(mod, fun, [val]) do
      :ok -> :ok
      {:ok, _} -> :ok
      err -> err
    end
  end

  defp validate_field(val, {:custom, {mod, fun, args}}, _data) do
    case apply(mod, fun, [val | args]) do
      :ok -> :ok
      {:ok, _} -> :ok
      err -> err
    end
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
      template = "expected either <%= first_type %> or <%= second_type %>, got: <%= actual %>"
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
        template = "expected one of <%= oneof %>, got: <%= actual %>"

        {:error, template, info}
    end)
  end

  defp validate_field(val, {:tuple, types}, data) when is_tuple(val) do
    if tuple_size(val) == length(types) do
      Enum.with_index(types)
      |> Enum.reduce_while(:ok, fn {type, index}, :ok ->
        case validate_field(elem(val, index), type, data) do
          :ok ->
            {:cont, :ok}

          {:error, reason, nested_info} ->
            info = [index: index] ++ nested_info
            {:halt, {:error, "tuple element <%= index %>: #{reason}", info}}
        end
      end)
    else
      info = [length: length(types), actual: length(Tuple.to_list(val))]
      template = "expected tuple of size <%= length %> received tuple wwith <%= actual %> length"
      {:error, template, info}
    end
  end

  defp validate_field(val, {:enum, choices}, _data) do
    if to_string(val) in Enum.map(choices, &to_string/1) do
      :ok
    else
      info = [choices: inspect(choices, pretty: true), actual: inspect(val)]
      template = "expected one of <%= choices %> received <%= actual %>"
      {:error, template, info}
    end
  end

  defp validate_field(data, {:list, type}, source) when is_list(data) do
    Enum.reduce_while(data, :ok, fn el, :ok ->
      case validate_field(el, type, source) do
        :ok -> {:cont, :ok}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, reason, info} -> {:halt, {:error, reason, info}}
      end
    end)
  end

  defp validate_field(data, schema, _data) when is_enumerable(data) do
    case traverse_schema(schema, data) do
      {[], _path} -> :ok
      {errors, _path} -> {:error, errors}
    end
  end

  defp validate_field(val, type, _data) do
    info = [expected: type, actual: inspect(val, pretty: true)]
    {:error, "expected type of <%= expected %> received <%= actual %> value", info}
  end

  def validate_schema(schema) when is_enumerable(schema) do
    case traverse_definition(schema) do
      {[], _path} -> {:ok, schema}
      {errors, _path} -> {:error, errors}
    end
  end

  def validate_schema(schema) do
    case validate_type(schema) do
      :ok ->
        {:ok, schema}

      {:error, reason, info} ->
        msg = EEx.eval_string(reason, info)
        err = %Peri.Error{message: msg, content: info}

        {:error, err}
    end
  end

  defp traverse_definition(schema) when is_enumerable(schema) do
    Enum.reduce(schema, {[], []}, fn {key, type}, {errors, path} ->
      case validate_type(type) do
        :ok ->
          {errors, []}

        {:error, [%Peri.Error{} = nested_err | _]} ->
          current_path = path ++ [key]
          nested_error = update_error_paths(nested_err, current_path)
          err = %Peri.Error{path: current_path, key: key, errors: [nested_error]}
          {[err | errors], path}

        {:error, reason, info} ->
          msg = EEx.eval_string(reason, info)
          current_path = path ++ [key]
          info = [{:schema, schema} | info]
          err = %Peri.Error{path: current_path, message: msg, content: info, key: key}

          {[err | errors], path}
      end
    end)
  end

  defp validate_type(nil), do: :ok
  defp validate_type(:any), do: :ok
  defp validate_type(:atom), do: :ok
  defp validate_type(:integer), do: :ok
  defp validate_type(:map), do: :ok
  defp validate_type(:float), do: :ok
  defp validate_type(:boolean), do: :ok
  defp validate_type(:string), do: :ok
  defp validate_type({:enum, choices}) when is_list(choices), do: :ok
  defp validate_type({:required, type}), do: validate_type(type)
  defp validate_type({:list, type}), do: validate_type(type)
  defp validate_type({:custom, cb}) when is_function(cb, 1), do: :ok
  defp validate_type({:custom, {mod, fun}}) when is_atom(mod) and is_atom(fun), do: :ok

  defp validate_type({:custom, {mod, fun, args}})
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: :ok

  defp validate_type({:cond, cb, type, else_type}) when is_function(cb, 1) do
    with :ok <- validate_type(type) do
      validate_type(else_type)
    end
  end

  defp validate_type({:dependent, _, cb, type}) when is_function(cb, 1) do
    validate_type(type)
  end

  defp validate_type({:tuple, types}) do
    Enum.reduce_while(types, :ok, fn type, :ok ->
      case validate_type(type) do
        :ok -> {:cont, :ok}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, template, info} -> {:halt, {:error, template, info}}
      end
    end)
  end

  defp validate_type({:either, {type_1, type_2}}) do
    with :ok <- validate_type(type_1) do
      validate_type(type_2)
    end
  end

  defp validate_type({:oneof, types}) do
    Enum.reduce_while(types, :ok, fn type, :ok ->
      case validate_type(type) do
        :ok -> {:cont, :ok}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, template, info} -> {:halt, {:error, template, info}}
      end
    end)
  end

  defp validate_type(schema) when is_enumerable(schema) do
    case traverse_definition(schema) do
      {[], _path} -> :ok
      {errors, _path} -> {:error, errors}
    end
  end

  defp validate_type(invalid) do
    invalid = inspect(invalid, pretty: true)
    {:error, "invalid schema definition: <%= invalid %>", invalid: invalid}
  end
end
