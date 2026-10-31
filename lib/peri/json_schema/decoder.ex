defmodule Peri.JSONSchema.Decoder do
  @moduledoc """
  Decodes a JSON Schema (Draft 7) map into a Peri schema definition.

  Returns `{:ok, schema}` on success or `{:error, errors}` if the resulting
  Peri schema fails `Peri.validate_schema/1`.

  Recursive local references and `allOf` intersections that Peri cannot
  represent return `{:error, reason}` instead of being expanded or merged
  into a schema with different validation semantics. `oneOf` is represented
  as Peri's first-success union and therefore behaves like `anyOf`.

  Prefer `Peri.from_json_schema/1` as the public entry point.
  """

  @spec decode(map, list(opt)) :: {:ok, Peri.schema()} | {:error, term}
        when opt: {:keys, :strings | :atoms | :atoms!}
  def decode(json_schema, opts) when is_map(json_schema) do
    keys = Keyword.get(opts, :keys, :strings)

    definitions =
      Map.get(json_schema, "definitions", %{})
      |> Map.merge(Map.get(json_schema, "$defs", %{}))

    Process.put(:peri_json_schema_defs_in, definitions)
    Process.put(:peri_json_schema_refs_in, [])

    try do
      schema = convert_schema(json_schema, keys)
      Peri.validate_schema(schema)
    catch
      {:peri_json_schema_error, reason} -> {:error, reason}
    after
      Process.delete(:peri_json_schema_defs_in)
      Process.delete(:peri_json_schema_refs_in)
    end
  end

  defp convert_schema(%{"enum" => values, "type" => type} = schema, keys_opts)
       when is_list(values) and is_binary(type) do
    case type do
      "integer" -> {:enum, numeric_enum_values(values), type: integer_schema(schema)}
      "number" -> {:enum, numeric_enum_values(values), type: number_schema(schema)}
      _ -> decode_enum(values, type, keys_opts)
    end
  end

  defp convert_schema(%{"type" => "object"} = schema, keys_opts),
    do: convert_object(schema, keys_opts)

  defp convert_schema(%{"type" => "array"} = schema, keys_opt),
    do: convert_array(schema, keys_opt)

  defp convert_schema(%{"type" => "string"} = schema, _), do: convert_string(schema)
  defp convert_schema(%{"type" => "number"} = schema, _), do: convert_number(schema)
  defp convert_schema(%{"type" => "integer"} = schema, _), do: convert_integer(schema)
  defp convert_schema(%{"type" => "boolean"}, _), do: :boolean
  defp convert_schema(%{"type" => "null"}, _), do: {:literal, nil}

  defp convert_schema(%{"type" => types} = schema, keys_opt) when is_list(types) do
    schemas =
      Enum.map(types, fn type -> convert_schema(Map.put(schema, "type", type), keys_opt) end)

    case schemas do
      [single] -> single
      [a, b] -> {:either, {a, b}}
      multiple -> {:oneof, multiple}
    end
  end

  defp convert_schema(%{"$ref" => ref}, keys_opt)
       when is_binary(ref) do
    name =
      case ref do
        "#/$defs/" <> name -> name
        "#/definitions/" <> name -> name
        _ -> nil
      end

    if is_nil(name), do: :any, else: resolve_ref(name, keys_opt)
  end

  defp convert_schema(%{"const" => value}, _), do: {:literal, value}
  defp convert_schema(%{"enum" => values}, _) when is_list(values), do: {:enum, values}

  defp convert_schema(%{"oneOf" => schemas}, keys_opt) when is_list(schemas) do
    converted = Enum.map(schemas, &convert_schema(&1, keys_opt))

    case converted do
      [single] -> single
      [a, b] -> {:either, {a, b}}
      multiple -> {:oneof, multiple}
    end
  end

  # Peri's `:oneof` succeeds on the first matching branch, which mirrors
  # JSON Schema's `anyOf` semantics. JSON Schema's `oneOf` requires *exactly
  # one* match; Peri cannot express that constraint, so `oneOf` is decoded
  # to `:oneof` lossily (treated as `anyOf`).
  defp convert_schema(%{"anyOf" => schemas}, keys_opt) when is_list(schemas) do
    convert_schema(%{"oneOf" => schemas}, keys_opt)
  end

  defp convert_schema(%{"allOf" => schemas}, keys_opt) when is_list(schemas) do
    Enum.reduce(schemas, %{}, fn schema, acc ->
      case convert_schema(schema, keys_opt) do
        map when is_map(map) -> merge_all_of!(acc, map)
        other -> throw({:peri_json_schema_error, {:unsupported_all_of_branch, other}})
      end
    end)
  end

  defp convert_schema(%{"additionalProperties" => false}, _keys_opt), do: %{}

  defp convert_schema(%{"additionalProperties" => add_props}, keys_opt) when is_map(add_props) do
    {:map, convert_schema(add_props, keys_opt)}
  end

  defp convert_schema(%{"additionalProperties" => true}, _keys_opt), do: {:map, :any}

  defp convert_schema(_, _), do: :any

  defp decode_enum(values, type, keys_opts) do
    case decode_primitive(type, keys_opts) do
      nil -> {:enum, values}
      base -> {:enum, values, type: base}
    end
  end

  defp resolve_ref(name, keys_opt) do
    defs = Process.get(:peri_json_schema_defs_in, %{})
    refs = Process.get(:peri_json_schema_refs_in, [])

    case {name in refs, Map.fetch(defs, name)} do
      {true, _} ->
        throw({:peri_json_schema_error, {:recursive_ref, name}})

      {false, {:ok, def_schema}} ->
        Process.put(:peri_json_schema_refs_in, [name | refs])

        try do
          convert_schema(def_schema, keys_opt)
        after
          Process.put(:peri_json_schema_refs_in, refs)
        end

      {false, :error} ->
        :any
    end
  end

  defp decode_primitive("string", _), do: :string
  defp decode_primitive("integer", _), do: :integer
  defp decode_primitive("number", _), do: :float
  defp decode_primitive("boolean", _), do: :boolean
  defp decode_primitive(_, _), do: nil

  defp convert_object(%{"properties" => properties} = schema, keys_opt) do
    required = Map.get(schema, "required", [])

    properties =
      Map.new(properties, fn {key, prop_schema} ->
        peri_type = convert_schema(prop_schema, keys_opt)
        final = if key in required, do: {:required, peri_type}, else: peri_type
        {safe_key(key, keys_opt), final}
      end)

    case Map.fetch(schema, "additionalProperties") do
      {:ok, add_props} when is_map(add_props) ->
        {:schema, properties, {:additional_keys, convert_schema(add_props, keys_opt)}}

      {:ok, true} ->
        {:schema, properties, {:additional_keys, :any}}

      _ ->
        properties
    end
  end

  defp convert_object(%{"additionalProperties" => add_props}, keys_opt) when is_map(add_props) do
    {:map, convert_schema(add_props, keys_opt)}
  end

  defp convert_object(%{"additionalProperties" => true}, _keys_opt), do: {:map, :any}

  defp convert_object(%{"additionalProperties" => false}, _keys_opt), do: %{}

  defp convert_object(_, _), do: %{}

  defp safe_key(key, :strings) when is_binary(key), do: key

  defp safe_key(key, opt)
       when opt in [:atoms, :atoms!] and is_atom(key),
       do: key

  defp safe_key(key, :atoms!) when is_binary(key) do
    String.to_atom(key)
  end

  defp safe_key(key, :atoms) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp convert_array(%{"items" => items} = schema, keys_opt) do
    base = {:list, convert_schema(items, keys_opt)}
    apply_list_constraints(base, schema)
  end

  defp convert_array(schema, _) do
    apply_list_constraints({:list, :any}, schema)
  end

  defp apply_list_constraints({:list, item}, schema) do
    list_opts =
      []
      |> maybe_put(schema, "minItems", :min)
      |> maybe_put(schema, "maxItems", :max)
      |> maybe_put_unique(schema)

    if list_opts == [], do: {:list, item}, else: {:list, item, list_opts}
  end

  defp maybe_put(opts, schema, json_key, peri_key) do
    case Map.get(schema, json_key) do
      nil -> opts
      value -> opts ++ [{peri_key, value}]
    end
  end

  defp maybe_put_unique(opts, schema) do
    case Map.get(schema, "uniqueItems") do
      true -> opts ++ [unique: true]
      _ -> opts
    end
  end

  defp convert_string(schema) do
    :string
    |> apply_constraint(schema, "minLength", :min)
    |> apply_constraint(schema, "maxLength", :max)
    |> apply_constraint(schema, "pattern", fn pattern ->
      case Regex.compile(pattern) do
        {:ok, regex} -> {:regex, regex}
        {:error, _reason} -> nil
      end
    end)
    |> apply_constraint(schema, "format", fn format ->
      case format do
        "email" -> {:regex, ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/}
        "uri" -> {:regex, ~r/^[a-zA-Z][a-zA-Z\d+.-]*:/}
        "date" -> :date
        "time" -> :time
        "date-time" -> :datetime
        _ -> nil
      end
    end)
  end

  defp convert_number(schema), do: number_schema(schema)

  defp convert_integer(schema), do: integer_schema(schema)

  defp number_schema(schema) do
    {:either, {apply_numeric(:integer, schema), apply_numeric(:float, schema)}}
  end

  defp integer_schema(schema) do
    integer = apply_numeric(:integer, schema)
    integral_float = {:custom, {__MODULE__, :validate_integral_float, [schema]}}
    {:either, {integer, integral_float}}
  end

  @doc false
  def validate_integral_float(value, schema) when is_float(value) do
    if value == trunc(value) do
      Peri.validate(apply_numeric(:float, schema), value)
    else
      {:error, "expected an integer-valued number"}
    end
  end

  def validate_integral_float(_value, _schema), do: {:error, "expected an integer-valued number"}

  defp merge_all_of!(left, right) do
    Enum.reduce(right, left, fn {key, value}, acc ->
      case Map.fetch(acc, key) do
        :error ->
          Map.put(acc, key, value)

        {:ok, ^value} ->
          acc

        {:ok, existing} ->
          throw({:peri_json_schema_error, {:all_of_conflict, key, existing, value}})
      end
    end)
  end

  defp numeric_enum_values(values) do
    values
    |> Enum.flat_map(fn
      value when is_integer(value) -> [value | float_equivalent(value)]
      value when is_float(value) and value == trunc(value) -> [value, trunc(value)]
      value -> [value]
    end)
    |> Enum.uniq()
  end

  defp float_equivalent(value) do
    [value * 1.0]
  rescue
    ArithmeticError -> []
  end

  defp apply_numeric(base, schema) do
    base
    |> apply_constraint(schema, "minimum", :gte)
    |> apply_constraint(schema, "maximum", :lte)
    |> apply_constraint(schema, "exclusiveMinimum", :gt)
    |> apply_constraint(schema, "exclusiveMaximum", :lt)
    |> apply_constraint(schema, "multipleOf", :multiple_of)
  end

  defp apply_constraint({base, constraints}, schema, json_key, handler)
       when is_tuple(constraints) or is_list(constraints) do
    existing = List.wrap(constraints)

    case apply_constraint(base, schema, json_key, handler) do
      {_base, new_constraint} -> {base, existing ++ [new_constraint]}
      _base -> {base, constraints}
    end
  end

  defp apply_constraint(base, schema, json_key, peri_constraint) when is_atom(peri_constraint) do
    case Map.get(schema, json_key) do
      nil -> base
      value -> {base, {peri_constraint, value}}
    end
  end

  defp apply_constraint(base, schema, json_key, converter) when is_function(converter) do
    case Map.get(schema, json_key) do
      nil ->
        base

      value ->
        case converter.(value) do
          nil -> base
          {:regex, regex} when base == :string -> {:string, {:regex, regex}}
          :date -> :date
          :time -> :time
          :datetime -> :datetime
          constraint -> {base, constraint}
        end
    end
  end
end
