defmodule Peri.JSONSchema.Decoder do
  @moduledoc """
  Decodes a JSON Schema (Draft 7) map into a Peri schema definition.

  Returns `{:ok, schema}` on success or `{:error, errors}` if the resulting
  Peri schema fails `Peri.validate_schema/1`.

  Prefer `Peri.from_json_schema/1` as the public entry point.
  """

  @spec decode(map) :: {:ok, Peri.schema()} | {:error, term}
  def decode(json_schema) when is_map(json_schema) do
    schema = convert_schema(json_schema)
    Peri.validate_schema(schema)
  end

  defp convert_schema(%{"type" => "object"} = schema), do: convert_object(schema)
  defp convert_schema(%{"type" => "array"} = schema), do: convert_array(schema)
  defp convert_schema(%{"type" => "string"} = schema), do: convert_string(schema)
  defp convert_schema(%{"type" => "number"} = schema), do: convert_number(schema)
  defp convert_schema(%{"type" => "integer"} = schema), do: convert_integer(schema)
  defp convert_schema(%{"type" => "boolean"}), do: :boolean
  defp convert_schema(%{"type" => "null"}), do: {:literal, nil}

  defp convert_schema(%{"type" => types} = schema) when is_list(types) do
    schemas = Enum.map(types, fn type -> convert_schema(Map.put(schema, "type", type)) end)

    case schemas do
      [single] -> single
      [a, b] -> {:either, {a, b}}
      multiple -> {:oneof, multiple}
    end
  end

  defp convert_schema(%{"const" => value}), do: {:literal, value}
  defp convert_schema(%{"enum" => values}) when is_list(values), do: {:enum, values}

  defp convert_schema(%{"oneOf" => schemas}) when is_list(schemas) do
    converted = Enum.map(schemas, &convert_schema/1)

    case converted do
      [single] -> single
      [a, b] -> {:either, {a, b}}
      multiple -> {:oneof, multiple}
    end
  end

  defp convert_schema(%{"anyOf" => schemas}) when is_list(schemas) do
    convert_schema(%{"oneOf" => schemas})
  end

  defp convert_schema(%{"allOf" => schemas}) when is_list(schemas) do
    Enum.reduce(schemas, %{}, fn schema, acc ->
      case convert_schema(schema) do
        map when is_map(map) -> Map.merge(acc, map)
        _other -> acc
      end
    end)
  end

  defp convert_schema(%{"additionalProperties" => add_props}) when is_map(add_props) do
    {:map, convert_schema(add_props)}
  end

  defp convert_schema(_), do: :any

  defp convert_object(%{"properties" => properties} = schema) do
    required = Map.get(schema, "required", [])

    Map.new(properties, fn {key, prop_schema} ->
      peri_type = convert_schema(prop_schema)
      final = if key in required, do: {:required, peri_type}, else: peri_type
      {String.to_atom(key), final}
    end)
  end

  defp convert_object(%{"additionalProperties" => add_props}) when is_map(add_props) do
    {:map, convert_schema(add_props)}
  end

  defp convert_object(_), do: %{}

  defp convert_array(%{"items" => items}) do
    {:list, convert_schema(items)}
  end

  defp convert_array(_), do: {:list, :any}

  defp convert_string(schema) do
    :string
    |> apply_constraint(schema, "minLength", :min)
    |> apply_constraint(schema, "maxLength", :max)
    |> apply_constraint(schema, "pattern", fn pattern ->
      {:regex, Regex.compile!(pattern)}
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

  defp convert_number(schema) do
    :float
    |> apply_constraint(schema, "minimum", :gte)
    |> apply_constraint(schema, "maximum", :lte)
    |> apply_constraint(schema, "exclusiveMinimum", :gt)
    |> apply_constraint(schema, "exclusiveMaximum", :lt)
  end

  defp convert_integer(schema) do
    :integer
    |> apply_constraint(schema, "minimum", :gte)
    |> apply_constraint(schema, "maximum", :lte)
    |> apply_constraint(schema, "exclusiveMinimum", :gt)
    |> apply_constraint(schema, "exclusiveMaximum", :lt)
  end

  defp apply_constraint({base, constraint}, schema, json_key, handler)
       when is_tuple(constraint) do
    case apply_constraint(base, schema, json_key, handler) do
      {_base, new_constraint} -> {base, [constraint, new_constraint]}
      _base -> {base, constraint}
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
