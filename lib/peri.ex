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
  - `{:tuple, [type1, type2, ...]}` - Tuple with elements of specified types
  - `{:enum, [value1, value2, ...]}` - One of the specified values
  - `{:literal, value}` - Exactly matches the specified value
  - `{:either, {type1, type2}}` - Either type1 or type2
  - `{:oneof, [type1, type2, ...]}` - One of the specified types
  - Nested maps for complex structures

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

  @type validation :: (term -> :ok | {:error, template :: String.t(), context :: map | keyword})
  @type time_def :: :time | :date | :datetime | :naive_datetime
  @type string_def ::
          :string
          | {:string, {:regex, Regex.t()} | {:eq, String.t()} | {:min, integer} | {:max, integer}}
  @type int_def ::
          :integer
          | {:integer,
             {:eq, integer}
             | {:neq, integer}
             | {:lt, integer}
             | {:lte, integer}
             | {:gt, integer}
             | {:gte, integer}
             | {:range, {min :: integer, max :: integer}}}
  @type float_def ::
          :float
          | {:float,
             {:eq, float}
             | {:neq, float}
             | {:lt, float}
             | {:lte, float}
             | {:gt, float}
             | {:gte, :float}
             | {:range, {min :: float, max :: float}}}
  @type default_def ::
          {schema_def, {:default, term}}
          | {schema_def, {:default, (-> term)}}
          | {schema_def, {:default, {module, atom}}}
  @type transform_def ::
          {schema_def, {:transform, (term -> term) | (term, term -> term)}}
          | {schema_def, {:transform, {module, atom}}}
          | {schema_def, {:transform, {module, atom, list(term)}}}
  @type custom_def ::
          {:custom, (term -> term)}
          | {:custom, {module, atom}}
          | {:custom, {module, atom, list(term)}}
  @type cond_def ::
          {:cond, condition :: (term -> boolean), true_branch :: schema_def,
           else_branch :: schema_def}
  @type dependent_def ::
          {:dependent, field :: atom, validation, type :: schema_def}
          | {:dependent,
             (term ->
                {:ok, schema_def | nil}
                | {:error, template :: String.t(), context :: map | keyword})}
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
          | {:map, schema_def, schema_def}
          | {:tuple, list(schema_def)}
          | {:literal, literal}
          | time_def
          | string_def
          | int_def
          | float_def
          | default_def
          | transform_def
          | custom_def
  @type schema ::
          schema_def
          | %{String.t() => schema_def}
          | %{atom => schema_def}
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
  def conforms?(schema, data) do
    case validate(schema, data) do
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
    state = Peri.Parser.new(data, root_data: data)

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
  defp filter_data(_schema, data) when is_struct(data), do: data

  defp filter_data(schema, data) do
    acc = make_filter_data_accumulator(schema, data)

    Enum.reduce(schema, acc, fn {key, type}, acc ->
      string_key = to_string(key)
      value = get_enumerable_value(data, key)
      original_key = if enumerable_has_key?(data, key), do: key, else: string_key

      cond do
        is_enumerable(data) and not enumerable_has_key?(data, key) ->
          acc

        is_enumerable(value) and is_enumerable(type) ->
          nested_filtered_value = filter_data(type, value)
          put_in_enum(acc, original_key, nested_filtered_value)

        true ->
          put_in_enum(acc, original_key, value)
      end
    end)
    |> then(fn
      %{} = data -> data
      data when is_list(data) -> Enum.reverse(data)
    end)
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

  @doc false
  defp validate_field(nil, nil, _data), do: :ok
  defp validate_field(_, :any, _data), do: :ok
  defp validate_field(pid, :pid, _data) when is_pid(pid), do: :ok
  defp validate_field(%Date{}, :date, _data), do: :ok
  defp validate_field(%Time{}, :time, _data), do: :ok
  defp validate_field(%DateTime{}, :datetime, _data), do: :ok
  defp validate_field(%NaiveDateTime{}, :naive_datetime, _data), do: :ok
  defp validate_field(val, :atom, _data) when is_atom(val), do: :ok
  defp validate_field(val, :map, _data) when is_map(val), do: :ok
  defp validate_field(val, :string, _data) when is_binary(val), do: :ok
  defp validate_field(val, :integer, _data) when is_integer(val), do: :ok
  defp validate_field(val, :float, _data) when is_float(val), do: :ok
  defp validate_field(val, :boolean, _data) when is_boolean(val), do: :ok
  defp validate_field(val, :list, _data) when is_list(val), do: :ok

  defp validate_field(val, {:literal, literal}, _data) when val === literal, do: :ok

  defp validate_field(val, {:literal, literal}, _data) do
    {:error, "expected literal value %{expected} but got %{actual}",
     [expected: inspect(literal), actual: inspect(val)]}
  end

  defp validate_field(nil, {:required, type}, _data) do
    {:error, "is required, expected type of %{expected}", expected: type}
  end

  defp validate_field(_val, {:required, {type, {:default, default}}}, _data) do
    template =
      "cannot set default value of #{inspect(default)} for required field of type %{type}"

    {:ok, template, [type: type]}
  end

  defp validate_field(m, {:required, :map}, _data) when m == %{},
    do: {:error, "cannot be empty", []}

  defp validate_field(m, {:required, s}, _data) when m == %{} and is_map(s),
    do: {:error, "cannot be empty", []}

  defp validate_field([], {:required, {:list, _}}, _data), do: {:error, "cannot be empty", []}
  defp validate_field(val, {:required, type}, data), do: validate_field(val, type, data)

  defp validate_field(val, {:string, {:regex, regex}}, _data) when is_binary(val) do
    if Regex.match?(regex, val) do
      :ok
    else
      {:error, "should match the %{regex} pattern", [regex: regex]}
    end
  end

  defp validate_field(val, {:string, {:eq, eq}}, _data) when is_binary(val) do
    if val === eq do
      :ok
    else
      {:error, "should be equal to literal %{literal}", [literal: eq]}
    end
  end

  defp validate_field(val, {:string, {:min, min}}, _data) when is_binary(val) do
    if String.length(val) >= min do
      :ok
    else
      {:error, "should have the minimum length of %{length}", [length: min]}
    end
  end

  defp validate_field(val, {:string, {:max, max}}, _data) when is_binary(val) do
    if String.length(val) <= max do
      :ok
    else
      {:error, "should have the maximum length of %{length}", [length: max]}
    end
  end

  defp validate_field(val, {type, {:eq, value}}, _data)
       when is_numeric_type(type) and is_numeric(val) do
    if val == value do
      :ok
    else
      {:error, "should be equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:neq, value}}, _data)
       when is_numeric_type(type) and is_numeric(val) do
    if val != value do
      :ok
    else
      {:error, "should be not equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:gt, value}}, _data)
       when is_numeric_type(type) and is_numeric(val) do
    if val > value do
      :ok
    else
      {:error, "should be greater then %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:gte, value}}, _data)
       when is_numeric_type(type) and is_numeric(val) do
    if val >= value do
      :ok
    else
      {:error, "should be greater then or equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:lte, value}}, _data)
       when is_numeric_type(type) and is_numeric(val) do
    if val <= value do
      :ok
    else
      {:error, "should be less then or equal to %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:lt, value}}, _data)
       when is_numeric_type(type) and is_numeric(val) do
    if val < value do
      :ok
    else
      {:error, "should be less then %{value}", [value: value]}
    end
  end

  defp validate_field(val, {type, {:range, {min, max}}}, _data)
       when is_numeric_type(type) and is_numeric(val) do
    info = [min: min, max: max]
    template = "should be in the range of %{min}..%{max} (inclusive)"

    cond do
      val < min -> {:error, template, info}
      val > max -> {:error, template, info}
      true -> :ok
    end
  end

  defp validate_field(val, {type, {:default, {mod, fun}}}, data)
       when is_atom(mod) and is_atom(fun) do
    validate_field(val, {type, {:default, apply(mod, fun, [])}}, data)
  end

  defp validate_field(val, {type, {:default, {mod, fun, args}}}, data)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    validate_field(val, {type, {:default, apply(mod, fun, args)}}, data)
  end

  defp validate_field(val, {type, {:default, default}}, data)
       when is_function(default, 0) do
    validate_field(val, {type, {:default, default.()}}, data)
  end

  defp validate_field(val, {type, {:default, default}}, data) do
    val = if is_nil(val), do: default, else: val

    with :ok <- validate_field(val, type, data) do
      {:ok, val}
    end
  end

  defp validate_field(val, {:cond, condition, true_type, else_type}, parser) do
    root = maybe_get_root_data(parser)

    if condition.(root) do
      validate_field(val, true_type, parser)
    else
      validate_field(val, else_type, parser)
    end
  end

  defp validate_field(val, {:dependent, callback}, parser)
       when is_function(callback, 1) do
    root = maybe_get_root_data(parser)

    with {:ok, type} <- callback.(root),
         {:ok, schema} <- validate_schema(type) do
      validate_field(val, schema, parser)
    end
  end

  defp validate_field(val, {:dependent, {mod, fun}}, parser)
       when is_atom(mod) and is_atom(fun) do
    root = maybe_get_root_data(parser)

    with {:ok, type} <- apply(mod, fun, [root]),
         {:ok, schema} <- validate_schema(type) do
      validate_field(val, schema, parser)
    end
  end

  defp validate_field(val, {:dependent, {mod, fun, args}}, parser)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    root = maybe_get_root_data(parser)

    with {:ok, type} <- apply(mod, fun, [root | args]),
         {:ok, schema} <- validate_schema(type) do
      validate_field(val, schema, parser)
    end
  end

  defp validate_field(val, {:dependent, field, condition, type}, data) do
    dependent_val = get_enumerable_value(data, field)

    with :ok <- condition.(val, dependent_val) do
      validate_field(val, type, data)
    end
  end

  defp validate_field(nil, s, data) when is_enumerable(s) do
    validate_field(%{}, s, data)
  end

  defp validate_field(nil, _schema, _data), do: :ok

  defp validate_field(val, {type, {:transform, mapper}}, data)
       when is_function(mapper, 1) do
    case validate_field(val, type, data) do
      :ok -> {:ok, mapper.(val)}
      {:ok, val} -> {:ok, mapper.(val)}
      err -> err
    end
  end

  defp validate_field(val, {type, {:transform, mapper}}, data)
       when is_function(mapper, 2) do
    case validate_field(val, type, data) do
      :ok -> {:ok, mapper.(val, maybe_get_root_data(data))}
      {:ok, val} -> {:ok, mapper.(val, maybe_get_root_data(data))}
      err -> err
    end
  end

  defp validate_field(val, {type, {:transform, {mod, fun}}}, data)
       when is_atom(mod) and is_atom(fun) do
    with {:ok, val} <- validate_and_extract(val, type, data) do
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

  defp validate_field(val, {type, {:transform, {mod, fun, args}}}, data)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    with {:ok, val} <- validate_and_extract(val, type, data) do
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

  defp validate_field(val, {:either, {type_1, type_2}}, data) do
    with {:error, _} <- normalize_validation_result(validate_field(val, type_1, data)),
         {:error, _} <- normalize_validation_result(validate_field(val, type_2, data)) do
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

  defp validate_field(source, {:tuple, types}, data) when is_tuple(source) do
    if tuple_size(source) == length(types) do
      validate_tuple_elements(source, types, data)
    else
      info = [length: length(types), actual: length(Tuple.to_list(source))]
      template = "expected tuple of size %{length} received tuple with %{actual} length"
      {:error, template, info}
    end
  end

  defp validate_field(val, {:enum, choices}, _data) do
    if val in choices do
      :ok
    else
      info = [choices: inspect(choices, pretty: true), actual: inspect(val)]
      template = "expected one of %{choices} received %{actual}"
      {:error, template, info}
    end
  end

  defp validate_field(data, {:list, type}, source) when is_list(data) do
    Enum.reduce_while(data, {:ok, []}, fn el, {:ok, vals} ->
      case validate_field(el, type, source) do
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

  defp validate_field(data, {:map, type}, source) when is_map(data) do
    Enum.reduce_while(data, {:ok, %{}}, fn {key, val}, {:ok, map_acc} ->
      case validate_field(val, type, source) do
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

  defp validate_field(data, {:map, key_type, value_type}, source) when is_map(data) do
    Enum.reduce_while(data, {:ok, %{}}, fn {key, val}, {:ok, map_acc} ->
      with :ok <- validate_field(key, key_type, source),
           :ok <- validate_field(val, value_type, source) do
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

  defp validate_field(data, schema, _data)
       when is_enumerable(data) and not is_enumerable(schema) do
    {:error, "expected a nested schema but received schema: %{type}", [type: schema]}
  end

  defp validate_field(data, schema, p) when is_enumerable(data) do
    root = maybe_get_root_data(p)

    case traverse_schema(schema, Peri.Parser.new(data, root_data: root)) do
      %Peri.Parser{errors: []} = parser -> {:ok, parser.data}
      %Peri.Parser{errors: errors} -> {:error, errors}
    end
  end

  defp validate_field(val, type, _data) do
    info = [expected: type, actual: inspect(val, pretty: true)]
    {:error, "expected type of %{expected} received %{actual} value", info}
  end

  defp validate_tuple_elements(source, types, data) do
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
      {:ok, []} -> :ok
      {:ok, vals} -> {:ok, List.to_tuple(Enum.reverse(vals))}
      {:error, reason, info} -> {:error, reason, info}
    end)
  end

  #  Handles the validation step and extracts the value if valid
  defp validate_and_extract(val, type, data) do
    case validate_field(val, type, data) do
      :ok -> {:ok, val}
      {:ok, val} -> {:ok, val}
      err -> err
    end
  end

  # if schema is matches a raw data structure, it will not use the Peri.Parser
  defp maybe_get_root_data(%Peri.Parser{} = p), do: p.root_data
  defp maybe_get_root_data(data), do: data

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
  defp validate_type({:literal, _literal}, _parser), do: :ok
  defp validate_type(:date, _parser), do: :ok
  defp validate_type(:time, _parser), do: :ok
  defp validate_type(:datetime, _parser), do: :ok
  defp validate_type(:naive_datetime, _parser), do: :ok
  defp validate_type(:pid, _parser), do: :ok
  defp validate_type({type, {:default, _val}}, p), do: validate_type(type, p)
  defp validate_type({:enum, choices}, _) when is_list(choices), do: :ok

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

  defp validate_type({:dependent, cb}, _) when is_function(cb, 1), do: :ok

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

  if Code.ensure_loaded?(Ecto) do
    import Ecto.Changeset

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

      # TODO
      # definition = Peri.Ecto.parse(s)

      process_changeset(%{}, attrs)
    end

    defp process_changeset(definition, attrs) do
      nested =
        definition
        |> Enum.map(fn {key, def} -> {key, Map.take(def, [:type, :nested])} end)
        |> Enum.filter(fn {_, def} -> def.nested end)

      nested_keys = Enum.map(nested, fn {key, _} -> key end)

      {process_defaults(definition), process_types(definition)}
      |> cast(attrs, Map.keys(definition) -- nested_keys)
      |> process_validations(definition)
      |> process_required(definition)
      |> process_nested(nested)
    end

    defp process_defaults(definition) do
      definition
      |> Enum.map(fn {key, %{default: val}} -> {key, val} end)
      |> Enum.filter(fn {_key, default} -> default end)
      |> Map.new()
    end

    defp process_types(definition) do
      Map.new(definition, fn {key, %{type: type}} -> {key, type} end)
    end

    defp process_required(changeset, definition) do
      required =
        definition
        |> Enum.filter(fn {_key, %{required: required}} -> required end)
        |> Enum.map(fn {key, _} -> key end)

      validate_required(changeset, required)
    end

    defp process_validations(changeset, definition) do
      Enum.reduce(definition, changeset, fn {_, %{validations: vals}}, acc ->
        for validation <- vals, reduce: acc do
          changeset -> validation.(changeset)
        end
      end)
    end

    defp process_nested(changeset, nested) do
      Enum.reduce(nested, changeset, &handle_nested/2)
    end

    defp handle_nested({key, %{type: {:embed, %{cardinality: :one}}, nested: schema}}, acc) do
      cast_embed(acc, key,
        with: fn _source, attrs ->
          process_changeset(schema, attrs)
        end
      )
    end
  end

  # Helper functions

  # Normalize validation results to handle different error formats
  defp normalize_validation_result(:ok), do: :ok
  defp normalize_validation_result({:ok, val}), do: {:ok, val}
  defp normalize_validation_result({:error, reason, info}), do: {:error, [reason, info]}
  defp normalize_validation_result({:error, errors}), do: {:error, errors}
end
