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
  - **Type Constraints**: Supports various types including enums, lists, maps, tuples, literals, and more.

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
      preferences: {:map, :string},
      scores: {:map, :string, :integer},
      status: {:literal, :active},
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
    geolocation: {12.2, 34.2},
    preferences: %{"theme" => "dark", "notifications" => "enabled"},
    scores: %{"math" => 95, "science" => 92},
    status: :active,
    rating: 9
  }

  case MySchemas.user(user_data) do
    {:ok, valid_data} -> IO.puts("Data is valid!")
    {:error, errors} -> IO.inspect(errors, label: "Validation errors")
  end
  ```

  ## Error Handling

  Peri provides detailed error messages that include the path to the invalid data, the expected and actual values, and custom error messages for custom validations.

  ## Schema Types

  Peri supports the following schema types:

  - `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:map`, `:pid` - Basic types
  - `{:required, type}` - Mark a field as required
  - `{:list, type}` - List of elements of the given type
  - `{:map, type}` - Map with values of the given type
  - `{:map, key_type, value_type}` - Map with keys and values of specified types
  - `{:schema, schema}` - Explicitly tagged nested schema
  - `{:schema, map_schema, {:additional_keys, type}}` - Nested schema map, with extra entries validated using another type
  - `{:tuple, [type1, type2, ...]}` - Tuple with elements of specified types
  - `{:enum, [value1, value2, ...]}` - One of the specified values
  - `{:literal, value}` - Exactly matches the specified value
  - `{:either, {type1, type2}}` - Either type1 or type2
  - `{:oneof, [type1, type2, ...]}` - One of the specified types
  - `{:cond, condition, true_type, false_type}` - Conditional validation based on callback
  - `{:dependent, callback}` - Dynamic type based on callback result
  - Nested maps for complex structures

  ## Callback Functions for :cond and :dependent

  Both `:cond` and `:dependent` types support 1-arity and 2-arity callbacks:

  - **1-arity callbacks** receive the root data structure (backward compatible)
  - **2-arity callbacks** receive `(current, root)` where:
    - `current` is the data at the current validation context (e.g., list element)
    - `root` is the entire root data structure

  This is especially useful when validating elements within lists:

  ```elixir
  defschema :parent, %{
    items: {:list, %{
      type: :string,
      value: {:dependent, fn current, _root ->
        case current.type do
          "number" -> {:ok, :integer}
          "text" -> {:ok, :string}
          _ -> {:ok, :any}
        end
      end}
    }}
  }
  ```

  ## Functions

  - `validate/2` - Validates data against a schema.
  - `conforms?/2` - Checks if data conforms to a schema.
  - `validate_schema/1` - Validates the schema definition.
  - `generate/1` - Generates sample data based on schema (when StreamData is available).

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

  @type validation :: (term -> validation_result)
  @type validation_result :: :ok | {:error, template :: String.t(), context :: map | keyword}
  @type string_option ::
          {:regex, Regex.t()} | {:eq, String.t()} | {:min, integer} | {:max, integer}
  @type numeric_option(type) ::
          {:eq, type}
          | {:neq, type}
          | {:lt, type}
          | {:lte, type}
          | {:gt, type}
          | {:gte, type}
          | {:range, {min :: type, max :: type}}
  @type time_def :: :time | :date | :datetime | :naive_datetime | :duration
  @type string_def :: :string | {:string, string_option | list(string_option)}
  @type int_def :: :integer | {:integer, numeric_option(integer) | list(numeric_option(integer))}
  @type float_def :: :float | {:float, numeric_option(float) | list(numeric_option(float))}
  @type default_def ::
          {schema_def, {:default, term}}
          | {schema_def, {:default, (-> term)}}
          | {schema_def, {:default, {module, atom}}}
  @type transform_def ::
          {schema_def, {:transform, (term -> term) | (term, term -> term)}}
          | {schema_def, {:transform, {module, atom}}}
          | {schema_def, {:transform, {module, atom, list(term)}}}
  @type custom_def ::
          {:custom, validation}
          | {:custom, {module, atom}}
          | {:custom, {module, atom, list(term)}}
  @type cond_def ::
          {:cond, condition :: (term -> boolean), true_branch :: schema_def,
           else_branch :: schema_def}
          | {:cond, condition :: (current :: term, root :: term -> boolean),
             true_branch :: schema_def, else_branch :: schema_def}
  @type dependent_def ::
          {:dependent, field :: atom, validation, type :: schema_def}
          | {:dependent,
             (term ->
                {:ok, schema_def | nil}
                | {:error, template :: String.t(), context :: map | keyword})}
          | {:dependent,
             (current :: term, root :: term ->
                {:ok, schema_def | nil}
                | {:error, template :: String.t(), context :: map | keyword})}
  @type explicit_schema_def ::
          {:schema, schema}
          | {:schema, map_schema, {:additional_keys, schema_def}}
  @type literal :: integer | float | atom | String.t() | boolean
  @type schema_def ::
          :any
          | :atom
          | :boolean
          | :map
          | :pid
          | {:either, {schema_def, schema_def}}
          | {:oneof, list(schema_def)}
          | {:required, schema_def}
          | {:enum, list(term)}
          | {:list, schema_def}
          | {:map, schema_def}
          | {:map, key_type :: schema_def, value_type :: schema_def}
          | {:tuple, list(schema_def)}
          | {:literal, literal}
          | time_def
          | string_def
          | int_def
          | float_def
          | default_def
          | transform_def
          | custom_def
  @type map_schema :: %{(String.t() | atom) => schema_def}
  @type schema ::
          schema_def
          | map_schema
          | [{atom, schema_def}]

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

        # With permissive mode
        defschema :flexible_user, %{
          name: :string,
          email: {:required, :string}
        }, mode: :permissive
      end

      user_data = %{name: "John", age: 30, email: "john@example.com"}
      MySchemas.user(user_data)
      # => {:ok, %{name: "John", age: 30, email: "john@example.com"}}

      invalid_data = %{name: "John", age: 30}
      MySchemas.user(invalid_data)
      # => {:error, [email: "is required"]}

      # Permissive mode preserves extra fields
      flexible_data = %{name: "John", email: "john@example.com", role: "admin"}
      MySchemas.flexible_user(flexible_data)
      # => {:ok, %{name: "John", email: "john@example.com", role: "admin"}}
  """
  defmacro defschema(name, schema, opts \\ []) do
    bang = :"#{name}!"

    quote do
      def get_schema(unquote(name)) do
        unquote(schema)
      end

      if Code.ensure_loaded?(Ecto) do
        def unquote(:"#{name}_changeset")(data) do
          Peri.to_changeset!(unquote(schema), data)
        end
      end

      def unquote(name)(data) do
        with {:ok, schema} <- Peri.validate_schema(unquote(schema)) do
          Peri.validate(schema, data, unquote(opts))
        end
      end

      def unquote(bang)(data) do
        with {:ok, valid_schema} <- Peri.validate_schema(unquote(schema)),
             {:ok, valid_data} <- Peri.validate(valid_schema, data, unquote(opts)) do
          valid_data
        else
          {:error, errors} -> raise Peri.InvalidSchema, errors
        end
      end
    end
  end

  @doc """
  Checks if the given data is an enumerable, specifically a map or a list.

  ## Parameters

    - `data`: The data to check.

  ## Examples

      iex> is_enumerable(%{})
      true

      iex> is_enumerable([])
      true

      iex> is_enumerable(123)
      false

      iex> is_enumerable("string")
      false
  """
  defguard is_enumerable(data) when is_map(data) or is_list(data)

  @doc """
  Checks if the given data conforms to the specified schema.

  ## Parameters

    - `schema`: The schema definition to validate against.
    - `data`: The data to be validated.

  ## Options

    - `:mode` - Validation mode. Can be `:strict` (default) or `:permissive`.
      - `:strict` - Only fields defined in the schema are returned.
      - `:permissive` - All fields from the input data are preserved.

  ## Returns

    - `true` if the data conforms to the schema.
    - `false` if the data does not conform to the schema.

  ## Examples

      iex> schema = %{name: :string, age: :integer}
      iex> data = %{name: "Alice", age: 30}
      iex> Peri.conforms?(schema, data)
      true

      iex> invalid_data = %{name: "Alice", age: "thirty"}
      iex> Peri.conforms?(schema, invalid_data)
      false
  """
  def conforms?(schema, data, opts \\ []) do
    mode = Keyword.get(opts, :mode, :strict)

    case validate(schema, data, mode: mode) do
      {:ok, _} -> true
      {:error, _errors} -> false
    end
  end

  if Code.ensure_loaded?(StreamData) do
    @doc """
    Generates sample data based on the given schema definition using `StreamData`.

    This function validates the schema first, and if the schema is valid, it uses the
    `Peri.Generatable.gen/1` function to generate data according to the schema.

    Note that this function returns a `Stream`, so you traverse easily the data generations.

    ## Parameters

      - `schema`: The schema definition to generate data for.

    ## Returns

      - `{:ok, stream}` if the data is successfully generated.
      - `{:error, errors}` if there are validation errors in the schema.

    ## Examples

        iex> schema = %{name: :string, age: {:integer, {:range, {18, 65}}}}
        iex> {:ok, stream} = Peri.generate(schema)
        iex> [data] = Enum.take(stream, 1)
        iex> is_map(data)
        true
        iex> data[:age] in 18..65
        true

    """
    def generate(schema) do
      with {:ok, schema} <- validate_schema(schema) do
        {:ok, Peri.Generatable.gen(schema)}
      end
    end
  end

  @doc """
  Validates a given data map against a schema with options.

  Returns `{:ok, data}` if the data is valid according to the schema, or `{:error, errors}` if there are validation errors.

  ## Parameters

    - schema: The schema definition map.
    - data: The data map to be validated.
    - opts: Options for validation.

  ## Options

    - `:mode` - Validation mode. Can be `:strict` (default) or `:permissive`.
      - `:strict` - Only fields defined in the schema are returned.
      - `:permissive` - All fields from the input data are preserved.

  ## Examples

      schema = %{name: :string, age: :integer}
      data = %{name: "John", age: 30, extra: "field"}

      # Strict mode (default)
      Peri.validate(schema, data)
      # => {:ok, %{name: "John", age: 30}}

      # Permissive mode
      Peri.validate(schema, data, mode: :permissive)
      # => {:ok, %{name: "John", age: 30, extra: "field"}}
  """
  def validate(schema, data, opts \\ [])

  def validate(schema, data, opts) when is_enumerable(schema) and is_enumerable(data) do
    mode = Keyword.get(opts, :mode, :strict)

    if mode not in [:strict, :permissive] do
      raise ArgumentError, "Invalid mode: #{inspect(mode)}. Must be :strict or :permissive"
    end

    data = filter_data(schema, data, mode: mode)
    state = Peri.Parser.new(data, root_data: data)

    case traverse_schema(schema, state, mode: mode) do
      %Peri.Parser{errors: [], data: result} -> {:ok, result}
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  def validate(schema, data, opts) do
    case validate_field(data, schema, data, opts) do
      :ok ->
        {:ok, data}

      {:ok, result} ->
        {:ok, result}

      {:error, errors} ->
        {:error, errors}

      {:error, reason, info} ->
        {:error, Peri.Error.new_single(reason, info)}
    end
  end

  @doc """
  Helper function to put a value into an enum, handling
  not only maps and keyword lists but also structs.

  ## Examples

      iex> Peri.put_in_enum(%{}, :hello, "world")
      iex> Peri.put_in_enum(%{}, "hello", "world")
      iex> Peri.put_in_enum(%User{}, :hello, "world")
      iex> Peri.put_in_enum([], :hello, "world")
  """
  def put_in_enum(enum, key, val) when is_struct(enum) do
    struct(enum, %{key => val})
  end

  def put_in_enum(enum, key, val) when is_map(enum) do
    put_in(enum, [Access.key(key)], val)
  end

  def put_in_enum(enum, key, val) when is_list(enum) do
    put_in(enum[key], val)
  end

  # if data is struct, well, we do not need to filter it
  defp filter_data(_schema, data, _opts) when is_struct(data), do: data

  defp filter_data(schema, data, opts) do
    mode = Keyword.get(opts, :mode, :strict)

    if mode == :permissive do
      data
    else
      acc = make_filter_data_accumulator(schema, data)
      result = Enum.reduce(schema, acc, &do_filter_data(data, &1, &2, opts))
      if is_list(result), do: Enum.reverse(result), else: result
    end
  end

  defp do_filter_data(data, {key, type}, acc, opts) do
    string_key = to_string(key)
    value = get_enumerable_value(data, key)
    original_key = if enumerable_has_key?(data, key), do: key, else: string_key

    cond do
      is_enumerable(data) and not enumerable_has_key?(data, key) ->
        acc

      is_enumerable(value) and is_enumerable(type) ->
        nested_filtered_value = filter_data(type, value, opts)
        put_in_enum(acc, original_key, nested_filtered_value)

      true ->
        put_in_enum(acc, original_key, value)
    end
  end

  # we need to build structs after validating schema
  defp make_filter_data_accumulator(_schema, data) when is_struct(data) do
    %{__struct__: data.__struct__}
  end

  defp make_filter_data_accumulator(schema, _data) when is_map(schema), do: %{}
  defp make_filter_data_accumulator(schema, _data) when is_list(schema), do: []

  defp enumerable_has_key?(data, key) when is_struct(data) do
    !!get_in(data, [Access.key(key)])
  end

  defp enumerable_has_key?(data, key) when is_map(data) and is_binary(key) do
    Map.has_key?(data, key)
  end

  defp enumerable_has_key?(data, key) when is_map(data) and is_atom(key) do
    Map.has_key?(data, key) or enumerable_has_key?(data, Atom.to_string(key))
  end

  defp enumerable_has_key?(data, key) when is_list(data) do
    Keyword.has_key?(data, key)
  end

  @doc false
  defp traverse_schema(schema, %Peri.Parser{} = state, opts, path \\ []) do
    Enum.reduce(schema, state, fn {key, type}, parser ->
      value = get_enumerable_value(parser.data, key)

      case validate_field(value, type, parser, opts) do
        :ok ->
          parser

        {:ok, value} ->
          Peri.Parser.update_data(parser, key, value)

        {:error, [_ | _] = nested_errs} ->
          reduce_errors(path, key, nested_errs, parser)

        {:error, reason, info} ->
          err = Peri.Error.new_child(path, key, reason, info)
          Peri.Parser.add_error(parser, err)
      end
    end)
  end

  # Access.key/1 only support maps and structs
  def get_enumerable_value(enum, key) when is_struct(enum) do
    get_in(enum, [Access.key(key)])
  end

  def get_enumerable_value(enum, key) when is_map(enum) and is_binary(key) do
    Map.get(enum, key)
  end

  def get_enumerable_value(enum, key) when is_map(enum) and is_atom(key) do
    if Map.has_key?(enum, key) do
      Map.get(enum, key)
    else
      get_enumerable_value(enum, Atom.to_string(key))
    end
  end

  def get_enumerable_value(enum, key) when is_list(enum) do
    Keyword.get(enum, key)
  end

  @doc """
  Checks if the given data is a numeric value, specifically a integer or a float.

  ## Parameters

    - `data`: The data to check.

  ## Examples

      iex> is_numeric(123)
      true

      iex> is_numeric(0xFF)
      true

      iex> is_numeric(12.12)
      true

      iex> is_numeric("string")
      false

      iex> is_numeric(%{})
      false
  """
  defguard is_numeric(n) when is_integer(n) or is_float(n)

  @doc """
  Checks if the given type as an atom is a numeric (integer or float).

  ## Parameters

    - `data`: The data to check.

  ## Examples

      iex> is_numeric(:integer)
      true

      iex> is_numeric(:float)
      true

      iex> is_numeric(:list)
      false

      iex> is_numeric({:enum, _})
      false
  """
  defguard is_numeric_type(t) when t in [:integer, :float]

  defguard is_type_with_multiple_options(t) when is_numeric_type(t) or t === :string

  @doc false
  defp validate_field(nil, nil, _data, _opts), do: :ok
  defp validate_field(_, :any, _data, _opts), do: :ok
  defp validate_field(pid, :pid, _data, _opts) when is_pid(pid), do: :ok
  defp validate_field(%Date{}, :date, _data, _opts), do: :ok
  defp validate_field(%Time{}, :time, _data, _opts), do: :ok
  defp validate_field(%Duration{}, :duration, _data, _opts), do: :ok
  defp validate_field(%DateTime{}, :datetime, _data, _opts), do: :ok
  defp validate_field(%NaiveDateTime{}, :naive_datetime, _data, _opts), do: :ok
  defp validate_field(val, :atom, _data, _opts) when is_atom(val), do: :ok
  defp validate_field(val, :map, _data, _opts) when is_map(val), do: :ok
  defp validate_field(val, :string, _data, _opts) when is_binary(val), do: :ok
  defp validate_field(val, :integer, _data, _opts) when is_integer(val), do: :ok
  defp validate_field(val, :float, _data, _opts) when is_float(val), do: :ok
  defp validate_field(val, :boolean, _data, _opts) when is_boolean(val), do: :ok
  defp validate_field(val, :list, _data, _opts) when is_list(val), do: :ok

  defp validate_field(val, {:literal, literal}, _data, _opts) when val === literal, do: :ok

  defp validate_field(val, {:literal, literal}, _data, _opts) do
    {:error, "expected literal value %{expected} but got %{actual}",
     [expected: inspect(literal), actual: inspect(val)]}
  end

  defp validate_field(nil, {:required, type}, _data, _opts) do
    {:error, "is required, expected type of %{expected}", expected: type}
  end

  defp validate_field(_val, {:required, {type, {:default, default}}}, _data, _opts) do
    template =
      "cannot set default value of #{inspect(default)} for required field of type %{type}"

    {:ok, template, [type: type]}
  end

  # Empty maps and lists are valid for required fields - only nil is invalid
  defp validate_field(val, {:required, type}, data, opts),
    do: validate_field(val, type, data, opts)

  defp validate_field(val, {type, options}, data, opts)
       when is_type_with_multiple_options(type) and is_list(options) do
    options
    |> Enum.map(fn option -> validate_field(val, {type, option}, data, opts) end)
    |> Enum.filter(fn x -> x != :ok end)
    |> case do
      [] -> :ok
      errs -> {:error, errs}
    end
  end

  defp validate_field(val, {:string, {:regex, regex}}, _data, _opts) when is_binary(val) do
    if Regex.match?(regex, val) do
      :ok
    else
      {:error, "should match the %{regex} pattern", [regex: regex]}
    end
  end

  defp validate_field(val, {:string, {:eq, eq}}, _data, _opts) when is_binary(val) do
    if val === eq do
      :ok
    else
      {:error, "should be equal to literal %{literal}", [literal: eq]}
    end
  end

  defp validate_field(val, {:string, {:min, min}}, _data, _opts) when is_binary(val) do
    if String.length(val) >= min do
      :ok
    else
      {:error, "should have the minimum length of %{length}", [length: min]}
    end
  end

  defp validate_field(val, {:string, {:max, max}}, _data, _opts) when is_binary(val) do
    if String.length(val) <= max do
      :ok
    else
      {:error, "should have the maximum length of %{length}", [length: max]}
    end
  end

  defp validate_field(val, {type, {:eq, value}}, _data, _opts)
       when is_numeric_type(type) and is_numeric(val) do
    if val == value do
      :ok
    else
      {:error, "should be equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:neq, value}}, _data, _opts)
       when is_numeric_type(type) and is_numeric(val) do
    if val != value do
      :ok
    else
      {:error, "should be not equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:gt, value}}, _data, _opts)
       when is_numeric_type(type) and is_numeric(val) do
    if val > value do
      :ok
    else
      {:error, "should be greater then %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:gte, value}}, _data, _opts)
       when is_numeric_type(type) and is_numeric(val) do
    if val >= value do
      :ok
    else
      {:error, "should be greater then or equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:lte, value}}, _data, _opts)
       when is_numeric_type(type) and is_numeric(val) do
    if val <= value do
      :ok
    else
      {:error, "should be less then or equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:lt, value}}, _data, _opts)
       when is_numeric_type(type) and is_numeric(val) do
    if val < value do
      :ok
    else
      {:error, "should be less then %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:range, {min, max}}}, _data, _opts)
       when is_numeric_type(type) and is_numeric(val) do
    info = [min: min, max: max]
    template = "should be in the range of %{min}..%{max} (inclusive)"

    cond do
      val < min -> {:error, template, info}
      val > max -> {:error, template, info}
      true -> :ok
    end
  end

  defp validate_field(val, {type, {:default, {mod, fun}}}, data, opts)
       when is_atom(mod) and is_atom(fun) do
    validate_field(val, {type, {:default, apply(mod, fun, [])}}, data, opts)
  end

  defp validate_field(val, {type, {:default, {mod, fun, args}}}, data, opts)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    validate_field(val, {type, {:default, apply(mod, fun, args)}}, data, opts)
  end

  defp validate_field(val, {type, {:default, default}}, data, opts)
       when is_function(default, 0) do
    validate_field(val, {type, {:default, default.()}}, data, opts)
  end

  defp validate_field(val, {type, {:default, default}}, data, opts) do
    val = if is_nil(val), do: default, else: val

    with :ok <- validate_field(val, type, data, opts) do
      {:ok, val}
    end
  end

  defp validate_field(val, {:cond, condition, true_type, else_type}, parser, opts) do
    if call_callback(condition, parser) do
      validate_field(val, true_type, parser, opts)
    else
      validate_field(val, else_type, parser, opts)
    end
  end

  defp validate_field(val, {:dependent, callback}, parser, opts)
       when is_function(callback) do
    with {:ok, type} <- call_callback(callback, parser),
         {:ok, schema} <- validate_schema(type) do
      validate_field(val, schema, parser, opts)
    end
  end

  defp validate_field(val, {:dependent, {mod, fun}}, parser, opts)
       when is_atom(mod) and is_atom(fun) do
    result =
      cond do
        function_exported?(mod, fun, 2) ->
          current = maybe_get_current_data(parser)
          root = maybe_get_root_data(parser)
          apply(mod, fun, [current, root])

        function_exported?(mod, fun, 1) ->
          root = maybe_get_root_data(parser)
          apply(mod, fun, [root])
      end

    with {:ok, type} <- result,
         {:ok, schema} <- validate_schema(type) do
      validate_field(val, schema, parser, opts)
    end
  end

  defp validate_field(val, {:dependent, {mod, fun, args}}, parser, opts)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    root = maybe_get_root_data(parser)

    with {:ok, type} <- apply(mod, fun, [root | args]),
         {:ok, schema} <- validate_schema(type) do
      validate_field(val, schema, parser, opts)
    end
  end

  defp validate_field(val, {:dependent, field, condition, type}, parser, opts) do
    root = maybe_get_root_data(parser)
    dependent_val = get_enumerable_value(root, field)

    with :ok <- condition.(val, dependent_val) do
      validate_field(val, type, root, opts)
    end
  end

  defp validate_field(nil, s, data, opts) when is_enumerable(s) do
    validate_field(%{}, s, data, opts)
  end

  defp validate_field(nil, _schema, _data, _opts), do: :ok

  defp validate_field(val, {type, {:transform, mapper}}, data, opts)
       when is_function(mapper, 1) do
    case validate_field(val, type, data, opts) do
      :ok -> {:ok, mapper.(val)}
      {:ok, val} -> {:ok, mapper.(val)}
      err -> err
    end
  end

  defp validate_field(val, {type, {:transform, mapper}}, data, opts)
       when is_function(mapper, 2) do
    case validate_field(val, type, data, opts) do
      :ok -> {:ok, mapper.(val, maybe_get_root_data(data))}
      {:ok, val} -> {:ok, mapper.(val, maybe_get_root_data(data))}
      err -> err
    end
  end

  defp validate_field(val, {type, {:transform, {mod, fun}}}, data, opts)
       when is_atom(mod) and is_atom(fun) do
    with {:ok, val} <- validate_and_extract(val, type, data, opts) do
      cond do
        function_exported?(mod, fun, 1) ->
          {:ok, apply(mod, fun, [val])}

        function_exported?(mod, fun, 2) ->
          {:ok, apply(mod, fun, [val, maybe_get_root_data(data)])}

        true ->
          template = "expected %{mod} to export %{fun}/1 or %{fun}/2"
          {:error, template, mod: mod, fun: fun}
      end
    end
  end

  defp validate_field(val, {type, {:transform, {mod, fun, args}}}, data, opts)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    with {:ok, val} <- validate_and_extract(val, type, data, opts) do
      cond do
        function_exported?(mod, fun, length(args) + 2) ->
          {:ok, apply(mod, fun, [val, maybe_get_root_data(data) | args])}

        function_exported?(mod, fun, length(args) + 1) ->
          {:ok, apply(mod, fun, [val | args])}

        true ->
          template = "expected %{mod} to export %{fun} with arity from %{base} to %{arity}"
          {:error, template, mod: mod, fun: fun, arity: length(args), base: length(args) + 1}
      end
    end
  end

  defp validate_field(val, {:custom, callback}, _data, _opts) when is_function(callback, 1) do
    callback.(val)
  end

  defp validate_field(val, {:custom, {mod, fun}}, _data, _opts)
       when is_atom(mod) and is_atom(fun) do
    apply(mod, fun, [val])
  end

  defp validate_field(val, {:custom, {mod, fun, args}}, _data, _opts)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [val | args])
  end

  defp validate_field(val, {:either, {type_1, type_2}}, data, opts) do
    with {:error, _} <- normalize_validation_result(validate_field(val, type_1, data, opts)),
         {:error, _} <- normalize_validation_result(validate_field(val, type_2, data, opts)) do
      info = [first_type: type_1, second_type: type_2, actual: inspect(val)]
      template = "expected either %{first_type} or %{second_type}, got: %{actual}"
      {:error, template, info}
    end
  end

  defp validate_field(val, {:oneof, types}, data, opts) do
    types
    |> Enum.reduce_while(:error, fn type, :error ->
      case validate_field(val, type, data, opts) do
        :ok -> {:halt, :ok}
        {:ok, val} -> {:halt, {:ok, val}}
        {:error, _reason, _info} -> {:cont, :error}
        {:error, _errors} -> {:cont, :error}
      end
    end)
    |> then(fn
      :ok ->
        :ok

      {:ok, val} ->
        {:ok, val}

      :error ->
        expected = Enum.map_join(types, " or ", &inspect/1)
        info = [oneof: expected, actual: inspect(val)]
        template = "expected one of %{oneof}, got: %{actual}"

        {:error, template, info}
    end)
  end

  defp validate_field(source, {:tuple, types}, data, opts) when is_tuple(source) do
    if tuple_size(source) == length(types) do
      validate_tuple_elements(source, types, data, opts)
    else
      info = [length: length(types), actual: length(Tuple.to_list(source))]
      template = "expected tuple of size %{length} received tuple with %{actual} length"
      {:error, template, info}
    end
  end

  defp validate_field(val, {:enum, choices}, _data, _opts) do
    if val in choices do
      :ok
    else
      info = [choices: inspect(choices, pretty: true), actual: inspect(val)]
      template = "expected one of %{choices} received %{actual}"
      {:error, template, info}
    end
  end

  defp validate_field(data, {:list, type}, source, opts) when is_list(data) do
    data
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {el, index}, {:ok, vals} ->
      element_source =
        case source do
          %Peri.Parser{} = parser -> Peri.Parser.for_list_element(el, parser, index)
          _ -> source
        end

      case validate_field(el, type, element_source, opts) do
        :ok -> {:cont, {:ok, vals}}
        {:ok, val} -> {:cont, {:ok, [val | vals]}}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, reason, info} -> {:halt, {:error, reason, info}}
      end
    end)
    |> then(fn
      {:ok, []} -> :ok
      {:ok, val} -> {:ok, Enum.reverse(val)}
      err -> err
    end)
  end

  defp validate_field(data, {:map, type}, source, opts) when is_map(data) do
    Enum.reduce_while(data, {:ok, %{}}, fn {key, val}, {:ok, map_acc} ->
      case validate_field(val, type, source, opts) do
        :ok -> {:cont, {:ok, Map.put(map_acc, key, val)}}
        {:ok, validated_val} -> {:cont, {:ok, Map.put(map_acc, key, validated_val)}}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, reason, info} -> {:halt, {:error, reason, info}}
      end
    end)
    |> then(fn
      {:ok, map} when map == %{} -> :ok
      {:ok, map} -> {:ok, map}
      err -> err
    end)
  end

  defp validate_field(data, {:map, key_type, value_type}, source, opts) when is_map(data) do
    Enum.reduce_while(data, {:ok, %{}}, fn {key, val}, {:ok, map_acc} ->
      with :ok <- validate_field(key, key_type, source, opts),
           :ok <- validate_field(val, value_type, source, opts) do
        {:cont, {:ok, Map.put(map_acc, key, val)}}
      else
        {:ok, validated_val} ->
          {:cont, {:ok, Map.put(map_acc, key, validated_val)}}

        error ->
          {:halt, error}
      end
    end)
    |> then(fn
      {:ok, map} when map == %{} -> :ok
      {:ok, map} -> {:ok, map}
      err -> err
    end)
  end

  defp validate_field(data, {:schema, schema}, source, opts) do
    validate_field(data, schema, source, opts)
  end

  defp validate_field(
         data,
         {:schema, schema, {:additional_keys, value_schema}},
         source,
         opts
       )
       when is_map(data) and is_map(schema) do
    # Split data not in the schema so that the additional validator doesn't try
    # to validate over the defined keys.
    additional_keys =
      Enum.reduce(Map.keys(schema), MapSet.new(Map.keys(data)), fn key, acc ->
        acc |> MapSet.delete(key) |> MapSet.delete(to_string(key))
      end)

    additional_data =
      data
      |> Enum.filter(fn {key, _} -> MapSet.member?(additional_keys, key) end)
      |> Map.new()

    with {:ok, schema_data} <- validate_field(data, schema, source, opts),
         {:ok, additional_data} <-
           validate_field(additional_data, {:map, value_schema}, source, opts) do
      {:ok, Map.merge(schema_data, additional_data)}
    end
  end

  defp validate_field(data, schema, _data, _opts)
       when is_enumerable(data) and not is_enumerable(schema) do
    {:error, "expected a nested schema but received schema: %{type}", [type: schema]}
  end

  defp validate_field(data, schema, p, opts) when is_enumerable(data) do
    root = maybe_get_root_data(p)
    filtered_data = filter_data(schema, data, opts)

    case traverse_schema(schema, Peri.Parser.new(filtered_data, root_data: root), opts) do
      %Peri.Parser{errors: []} = parser -> {:ok, parser.data}
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  defp validate_field(val, type, _data, _opts) do
    info = [expected: type, actual: inspect(val, pretty: true)]
    {:error, "expected type of %{expected} received %{actual} value", info}
  end

  defp validate_tuple_elements(source, types, data, opts) do
    Enum.with_index(types)
    |> Enum.reduce_while({:ok, []}, fn {type, index}, {:ok, vals} ->
      case validate_field(elem(source, index), type, data, opts) do
        :ok ->
          {:cont, {:ok, vals}}

        {:ok, val} ->
          {:cont, {:ok, [val | vals]}}

        {:error, errors} when is_list(errors) ->
          info = [index: index]
          {:halt, {:error, "tuple element %{index}: invalid", info}}

        {:error, reason, nested_info} ->
          info = [index: index] ++ nested_info
          {:halt, {:error, "tuple element %{index}: #{reason}", info}}
      end
    end)
    |> then(fn
      {:ok, []} -> :ok
      {:ok, vals} -> {:ok, List.to_tuple(Enum.reverse(vals))}
      {:error, reason, info} -> {:error, reason, info}
    end)
  end

  defp validate_and_extract(val, type, data, opts) do
    case validate_field(val, type, data, opts) do
      :ok -> {:ok, val}
      {:ok, val} -> {:ok, val}
      err -> err
    end
  end

  # if schema is matches a raw data structure, it will not use the Peri.Parser
  defp maybe_get_root_data(%Peri.Parser{} = p), do: p.root_data
  defp maybe_get_root_data(data), do: data

  defp maybe_get_current_data(%Peri.Parser{} = p), do: p.current_data || p.data
  defp maybe_get_current_data(data), do: data

  defp call_callback(callback, parser) when is_function(callback, 1) do
    root = maybe_get_root_data(parser)
    callback.(root)
  end

  defp call_callback(callback, parser) when is_function(callback, 2) do
    current = maybe_get_current_data(parser)
    root = maybe_get_root_data(parser)
    callback.(current, root)
  end

  defp call_callback(callback, parser) do
    root = maybe_get_root_data(parser)
    callback.(root)
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
    case traverse_definition(schema, Peri.Parser.new(schema, root_data: schema)) do
      %Peri.Parser{errors: [], data: data} -> {:ok, data}
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  def validate_schema(schema) do
    case validate_type(schema, Peri.Parser.new(schema, root_data: schema)) do
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

        {:error, [_ | _] = nested_errs} ->
          reduce_errors(path, key, nested_errs, parser)

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
  defp validate_type({:literal, _literal}, _parser), do: :ok
  defp validate_type(:date, _parser), do: :ok
  defp validate_type(:time, _parser), do: :ok
  defp validate_type(:duration, _parser), do: :ok
  defp validate_type(:datetime, _parser), do: :ok
  defp validate_type(:naive_datetime, _parser), do: :ok
  defp validate_type(:pid, _parser), do: :ok
  defp validate_type({type, {:default, _val}}, p), do: validate_type(type, p)
  defp validate_type({:enum, choices}, _) when is_list(choices), do: :ok

  defp validate_type({type, options}, p)
       when is_type_with_multiple_options(type) and is_list(options) do
    Enum.reduce_while(options, :ok, fn option, :ok ->
      case validate_type({type, option}, p) do
        :ok -> {:cont, :ok}
        {:error, errors} -> {:halt, {:error, errors}}
        {:error, template, info} -> {:halt, {:error, template, info}}
      end
    end)
  end

  defp validate_type({:string, {:regex, %Regex{}}}, _p), do: :ok
  defp validate_type({:string, {:eq, eq}}, _p) when is_binary(eq), do: :ok
  defp validate_type({:string, {:min, min}}, _p) when is_integer(min), do: :ok
  defp validate_type({:string, {:max, max}}, _p) when is_integer(max), do: :ok

  defp validate_type({type, {:eq, val}}, _parer)
       when is_numeric_type(type) and is_numeric(val),
       do: :ok

  defp validate_type({type, {:neq, val}}, _parer)
       when is_numeric_type(type) and is_numeric(val),
       do: :ok

  defp validate_type({type, {:lt, val}}, _parer)
       when is_numeric_type(type) and is_numeric(val),
       do: :ok

  defp validate_type({type, {:lte, val}}, _parer)
       when is_numeric_type(type) and is_numeric(val),
       do: :ok

  defp validate_type({type, {:gt, val}}, _parer)
       when is_numeric_type(type) and is_numeric(val),
       do: :ok

  defp validate_type({type, {:gte, val}}, _parer)
       when is_numeric_type(type) and is_numeric(val),
       do: :ok

  defp validate_type({type, {:range, {min, max}}}, _parer)
       when is_numeric_type(type) and is_numeric(min) and is_numeric(max),
       do: :ok

  defp validate_type({type, {:transform, mapper}}, p) when is_function(mapper, 1),
    do: validate_type(type, p)

  defp validate_type({type, {:transform, mapper}}, p) when is_function(mapper, 2),
    do: validate_type(type, p)

  defp validate_type({type, {:transform, {_mod, _fun}}}, p),
    do: validate_type(type, p)

  defp validate_type({type, {:transform, {_mod, _fun, args}}}, p) when is_list(args),
    do: validate_type(type, p)

  defp validate_type({:required, {type, {:default, val}}}, _) do
    template = "cannot set default value of %{value} for required field of type %{type}"
    {:error, template, [value: val, type: type]}
  end

  defp validate_type({:required, type}, p), do: validate_type(type, p)
  defp validate_type({:list, type}, p), do: validate_type(type, p)
  defp validate_type({:map, type}, p), do: validate_type(type, p)

  defp validate_type({:map, key_type, value_type}, p) do
    with :ok <- validate_type(key_type, p) do
      validate_type(value_type, p)
    end
  end

  defp validate_type({:schema, type}, p), do: validate_type(type, p)

  defp validate_type({:schema, type, {:additional_keys, value_type}}, p) when is_map(type) do
    with :ok <- validate_type(type, p) do
      validate_type(value_type, p)
    end
  end

  defp validate_type({:custom, cb}, _) when is_function(cb, 1), do: :ok
  defp validate_type({:custom, {mod, fun}}, _) when is_atom(mod) and is_atom(fun), do: :ok

  defp validate_type({:custom, {mod, fun, args}}, _)
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: :ok

  defp validate_type({:cond, cb, type, else_type}, p)
       when is_function(cb, 1) or is_function(cb, 2) do
    with :ok <- validate_type(type, p) do
      validate_type(else_type, p)
    end
  end

  defp validate_type({:dependent, cb}, _) when is_function(cb, 1) or is_function(cb, 2), do: :ok

  defp validate_type({:dependent, {mod, fun}}, _) when is_atom(mod) and is_atom(fun), do: :ok

  defp validate_type({:dependent, {mod, fun, args}}, _)
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: :ok

  defp validate_type({:dependent, _, cb, type}, p) when is_function(cb, 2) do
    validate_type(type, p)
  end

  defp validate_type({:dependent, field, cb, type}, p)
       when is_atom(field) and is_function(cb, 2) do
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

  if Code.ensure_loaded?(Ecto) do
    @doc """
    Converts a `Peri.schema()` definition to an Ecto [schemaless changesets](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-schemaless-changesets).
    """
    @spec to_changeset!(schema, attrs :: map) :: Ecto.Changeset.t()
    def to_changeset!(s, _attrs) when not is_map(s) do
      raise Peri.Error,
        message:
          "currently Ecto doesn't support raw data structures or keyword lists validation, only maps"
    end

    def to_changeset!(%{} = s, %{} = attrs) do
      with {:error, err} <- Peri.validate_schema(s) do
        raise Peri.Error, err
      end

      definition = Peri.Ecto.parse(s)
      process_changeset(definition, attrs)
    end

    defp process_changeset(definition, attrs) do
      nested =
        definition
        |> Enum.map(fn {key, def} -> {key, Map.take(def, [:type, :nested])} end)
        |> Enum.filter(fn {_, def} -> def.nested end)

      nested_keys = Enum.map(nested, fn {key, _} -> key end)

      # Also exclude fields that need special validation
      special_keys =
        definition
        |> Enum.filter(fn {_, def} ->
          def[:type] == :any || def[:conditional]
        end)
        |> Enum.map(fn {key, _} -> key end)

      {process_defaults(definition), process_types(definition)}
      |> Ecto.Changeset.cast(attrs, Map.keys(definition) -- (nested_keys ++ special_keys))
      |> process_special_fields(special_keys, attrs, definition)
      |> process_validations(definition)
      |> process_required(definition)
      |> process_nested(nested, attrs)
    end

    defp process_defaults(definition) do
      definition
      |> Enum.map(fn {key, %{default: val}} -> {key, val} end)
      |> Enum.filter(fn {_key, default} -> default end)
      |> Map.new()
    end

    defp process_types(definition) do
      Map.new(definition, fn
        # Handle special cases for conditional and dependent types
        {key, %{condition: _} = def} -> {key, def[:type] || :string}
        {key, %{dependent_callback: _} = def} -> {key, def[:type] || :string}
        {key, %{depend: _} = def} -> {key, def[:type] || :string}
        # Handle cases where type is nil (either types sometimes don't set it)
        {key, %{type: nil} = _def} -> {key, :string}
        # Normal types
        {key, %{type: type}} -> {key, type}
        # Default fallback for any other pattern
        {key, _def} -> {key, :string}
      end)
    end

    defp process_required(changeset, definition) do
      # Get required fields, but exclude nested fields and conditional fields that will be processed separately
      required =
        definition
        |> Enum.filter(fn
          {_key, def} ->
            def[:required] == true &&
              is_nil(def[:nested]) &&
              not Map.get(def, :conditional, false)
        end)
        |> Enum.map(fn {key, _} -> key end)

      Ecto.Changeset.validate_required(changeset, required)
    end

    defp process_validations(changeset, definition) do
      Enum.reduce(definition, changeset, fn {_, %{validations: vals}}, acc ->
        for validation <- vals, reduce: acc do
          changeset -> validation.(changeset)
        end
      end)
    end

    defp process_nested(changeset, nested, attrs) do
      Enum.reduce(nested, changeset, &handle_nested(&1, &2, attrs))
    end

    defp handle_nested({key, def}, changeset, attrs) do
      value = get_nested_value(attrs, key)

      # First check if this nested field is required but missing
      if def[:required] && is_nil(value) do
        Ecto.Changeset.add_error(changeset, key, "can't be blank", validation: :required)
      else
        cond do
          def[:conditional] && def[:nested] ->
            # Let the validation handle it
            changeset

          match?({:embed, %{cardinality: _}}, def[:type]) ->
            {:embed, %{cardinality: cardinality}} = def[:type]
            validate_and_cast_nested(changeset, key, value, def[:nested], cardinality)

          match?({:parameterized, {Peri.Ecto.Type.OneOf, _}}, def[:type]) ->
            validate_composite_nested(changeset, key, value, def[:nested])

          match?({:parameterized, {Peri.Ecto.Type.Either, _}}, def[:type]) ->
            validate_composite_nested(changeset, key, value, def[:nested])

          true ->
            changeset
        end
      end
    end

    defp get_nested_value(attrs, key) do
      Map.get(attrs, key) || Map.get(attrs, to_string(key))
    end

    defp validate_and_cast_nested(changeset, _key, nil, _schema, _cardinality), do: changeset

    defp validate_and_cast_nested(changeset, key, value, schema, :one) do
      nested = process_changeset(schema, value)
      cast_nested_result(changeset, key, nested)
    end

    defp validate_and_cast_nested(changeset, key, values, schema, :many) when is_list(values) do
      results = Enum.map(values, &process_changeset(schema, &1))
      cast_nested_list_result(changeset, key, results)
    end

    defp validate_and_cast_nested(changeset, key, _value, _schema, :many) do
      Ecto.Changeset.add_error(changeset, key, "is invalid")
    end

    defp validate_composite_nested(changeset, _key, nil, _schemas), do: changeset

    defp validate_composite_nested(changeset, key, value, schemas) when is_map(value) do
      schemas
      |> Enum.find_value(fn {_, schema} ->
        case Peri.validate(schema, value) do
          {:ok, _} -> process_changeset(schema, value)
          _ -> nil
        end
      end)
      |> case do
        nil -> changeset
        nested -> cast_nested_result(changeset, key, nested)
      end
    end

    defp validate_composite_nested(changeset, _key, _value, _schemas), do: changeset

    defp process_special_fields(changeset, special_keys, attrs, definition) do
      Enum.reduce(special_keys, changeset, fn key, acc ->
        value = get_nested_value(attrs, key)
        process_special_field(acc, key, value, definition)
      end)
    end

    defp process_special_field(changeset, _key, nil, _definition), do: changeset

    defp process_special_field(changeset, key, value, _definition) do
      Ecto.Changeset.put_change(changeset, key, value)
    end

    defp cast_nested_result(changeset, key, nested) do
      if nested.valid? do
        # Keep the changeset in changes so get_change returns a changeset
        changes = Map.put(changeset.changes, key, nested)
        %{changeset | changes: changes, valid?: changeset.valid?}
      else
        transfer_nested_errors(changeset, key, nested)
      end
    end

    defp cast_nested_list_result(changeset, key, results) do
      all_valid =
        Enum.all?(results, fn
          %Ecto.Changeset{} = cs -> cs.valid?
          _ -> true
        end)

      if all_valid do
        # For valid results, keep the changesets in changes
        changes = Map.put(changeset.changes, key, results)
        %{changeset | changes: changes, valid?: changeset.valid?}
      else
        # For lists with errors, maintain the changeset structure
        changes = Map.put(changeset.changes, key, results)
        %{changeset | changes: changes, valid?: false}
      end
    end

    defp transfer_nested_errors(changeset, key, nested) do
      # For nested changesets, we need to put the invalid changeset in changes
      # so that traverse_errors can find it
      changes = Map.put(changeset.changes, key, nested)
      %{changeset | changes: changes, valid?: false}
    end
  end

  # Helper functions

  # Normalize validation results to handle different error formats
  defp normalize_validation_result(:ok), do: :ok
  defp normalize_validation_result({:ok, val}), do: {:ok, val}
  defp normalize_validation_result({:error, reason, info}), do: {:error, [reason, info]}
  defp normalize_validation_result({:error, errors}), do: {:error, errors}

  defp reduce_errors(path, key, [_ | _] = errors, parser) do
    Enum.reduce(errors, parser, fn
      %Peri.Error{} = err, parser ->
        err
        |> Peri.Error.update_error_paths(path ++ [key])
        |> then(&Peri.Error.new_parent(path, key, [&1]))
        |> then(&Peri.Parser.add_error(parser, &1))

      {:error, reason, info}, parser ->
        err = Peri.Error.new_child(path, key, reason, info)
        Peri.Parser.add_error(parser, err)
    end)
  end
end
