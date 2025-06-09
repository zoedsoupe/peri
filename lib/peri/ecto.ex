if Code.ensure_loaded?(Ecto) do
  defmodule Peri.Ecto do
    @moduledoc false

    import Ecto.Changeset

    alias Ecto.Embedded, as: Embed
    alias Peri.Ecto.Type

    require Peri

    @type validation ::
            {:eq, integer | float | String.t()}
            | {:neq, integer | float}
            | {:lt, integer | float}
            | {:lte, integer | float}
            | {:gt, integer | float}
            | {:gte, integer | float}
            | {:min, length :: integer}
            | {:max, length :: integer}
            | {:regex, pattern :: Regex.t()}
            | {:range, {min :: integer | float, max :: integer | float}}

    @type def :: %{
            atom => %{
              type: term,
              required: boolean,
              depend: path :: list(atom),
              default: term,
              validations: list(validation),
              nested: %{atom => def}
            }
          }

    defguard is_ecto_embed(data) when elem(data, 0) == :embed or elem(data, 0) == :parameterized

    def parse(%{} = schema) do
      init =
        Map.new(Map.keys(schema), fn key ->
          {key,
           %{
             required: nil,
             default: nil,
             validations: [],
             nested: nil
           }}
        end)

      Enum.reduce(schema, init, &parse_peri/2)
    end

    @raw_types ~w(atom string integer float boolean map date time datetime naive_datetime pid)a

    for type <- @raw_types do
      def parse_peri({key, unquote(type)}, ecto) do
        put_in(ecto[key][:type], Type.from(unquote(type)))
      end
    end

    def parse_peri({key, {:enum, _} = type}, ecto) do
      put_in(ecto[key][:type], Type.from(type))
    end

    def parse_peri({key, {:required, type}}, ecto) do
      ecto = put_in(ecto[key][:required], true)
      parse_peri({key, type}, ecto)
    end

    def parse_peri({key, {type, {:default, {mod, fun}}}}, ecto) do
      put_in(ecto[key][:default], apply(mod, fun, []))
      |> then(&parse_peri({key, type}, &1))
    end

    def parse_peri({key, {type, {:default, {mod, fun, args}}}}, ecto) do
      put_in(ecto[key][:default], apply(mod, fun, args))
      |> then(&parse_peri({key, type}, &1))
    end

    def parse_peri({key, {type, {:default, val}}}, ecto) do
      put_in(ecto[key][:default], val)
      |> then(&parse_peri({key, type}, &1))
    end

    def parse_peri({key, {:string, {:regex, regex}}}, ecto) do
      put_validation(ecto, key, fn changeset ->
        validate_format(changeset, key, regex)
      end)
      |> then(&parse_peri({key, :string}, &1))
    end

    def parse_peri({key, {:string, {:eq, eq}}}, ecto) do
      validation =
        &validate_change(&1, key, fn ^key, val ->
          if val === eq, do: [], else: [{key, "should be equal to literal #{eq}"}]
        end)

      put_validation(ecto, key, validation)
      |> then(&parse_peri({key, :string}, &1))
    end

    def parse_peri({key, {:string, {:min, min}}}, ecto) do
      put_validation(ecto, key, fn changeset ->
        validate_length(changeset, key, min: min)
      end)
      |> then(&parse_peri({key, :string}, &1))
    end

    def parse_peri({key, {:string, {:max, max}}}, ecto) do
      put_validation(ecto, key, fn changeset ->
        validate_length(changeset, key, max: max)
      end)
      |> then(&parse_peri({key, :string}, &1))
    end

    @number_checks [
      eq: :equal_to,
      neq: :not_equal_to,
      lt: :less_than,
      gt: :greater_than,
      lte: :less_than_or_equal_to,
      gte: :greater_than_or_equal_to
    ]

    for type <- [:integer, :float], {peri, check} <- @number_checks do
      def parse_peri({key, {unquote(type), {unquote(peri), val}}}, ecto) do
        put_validation(ecto, key, fn changeset ->
          validate_number(changeset, key, [{unquote(check), val}])
        end)
        |> then(&parse_peri({key, unquote(type)}, &1))
      end
    end

    for type <- [:integer, :float] do
      def parse_peri({key, {unquote(type), {:range, {min, max}}}}, ecto) do
        put_validation(ecto, key, fn changeset ->
          validate_number(changeset, key,
            greater_than_or_equal_to: min,
            less_than_or_equal_to: max
          )
        end)
        |> then(&parse_peri({key, unquote(type)}, &1))
      end
    end

    def parse_peri({key, {:list, type}}, ecto) when is_map(type) do
      ecto = put_in(ecto[key][:nested], parse(type))
      put_in(ecto[key][:type], embed_many(key))
    end

    def parse_peri({key, {:list, type}}, ecto) do
      put_in(ecto[key][:type], {:array, Type.from(type)})
    end

    def parse_peri({key, {:tuple, types}}, ecto) when is_list(types) do
      ecto = put_in(ecto[key][:type], Type.from({:tuple, types}))

      put_validation(ecto, key, fn changeset ->
        validate_tuple(changeset, key, types)
      end)
    end

    def parse_peri({key, type}, ecto) when is_map(type) do
      ecto = put_in(ecto[key][:nested], parse(type))
      put_in(ecto[key][:type], embed_one(key))
    end

    def parse_peri({key, {type, {:transform, mapper}}}, ecto) when is_function(mapper, 1) do
      ecto = parse_peri({key, type}, ecto)

      put_validation(ecto, key, fn changeset ->
        update_change(changeset, key, mapper)
      end)
    end

    def parse_peri({key, {type, {:transform, {mod, fun}}}}, ecto)
        when is_atom(mod) and is_atom(fun) do
      ecto = parse_peri({key, type}, ecto)

      put_validation(ecto, key, fn changeset ->
        update_change(changeset, key, &apply(mod, fun, [&1]))
      end)
    end

    def parse_peri({key, {type, {:transform, {mod, fun, args}}}}, ecto)
        when is_atom(mod) and is_atom(fun) and is_list(args) do
      ecto = parse_peri({key, type}, ecto)

      put_validation(ecto, key, fn changeset ->
        update_change(changeset, key, &apply(mod, fun, [&1 | args]))
      end)
    end

    def parse_peri({key, {:either, {fst, snd}}}, ecto) do
      nested_schemas = %{}

      nested_schemas =
        if is_map(fst) do
          Map.put(nested_schemas, "map_fst", parse(fst))
        else
          nested_schemas
        end

      nested_schemas =
        if is_map(snd) do
          Map.put(nested_schemas, "map_snd", parse(snd))
        else
          nested_schemas
        end

      ecto =
        if map_size(nested_schemas) > 0 do
          put_in(ecto[key][:nested], nested_schemas)
        else
          ecto
        end

      fst_type = if is_map(fst), do: :map, else: fst
      snd_type = if is_map(snd), do: :map, else: snd

      ecto = put_in(ecto[key][:type], Type.from({:either, {fst_type, snd_type}}))

      ecto = put_in(ecto[key][:original_fst], fst)
      ecto = put_in(ecto[key][:original_snd], snd)

      put_validation(ecto, key, fn changeset ->
        validate_either_type(changeset, key, fst, snd, ecto)
      end)
    end

    def parse_peri({key, {:oneof, types}}, ecto) when is_list(types) do
      if Enum.any?(types, &is_map/1) do
        {map_types, other_types} = Enum.split_with(types, &is_map/1)

        nested_schemas =
          Map.new(map_types, fn map_type ->
            {"map_#{System.unique_integer([:positive])}", parse(map_type)}
          end)

        ecto = put_in(ecto[key][:nested], nested_schemas)

        if other_types != [] do
          ecto = put_in(ecto[key][:type], Type.from({:oneof, other_types}))
          put_in(ecto[key][:original_types], types)
        else
          put_in(ecto[key][:type], :map)
        end
      else
        put_in(ecto[key][:type], Type.from({:oneof, types}))
      end
    end

    def parse_peri({key, {:cond, condition, true_type, else_type}}, ecto) do
      true_branch = parse_single_type(true_type)
      else_branch = parse_single_type(else_type)

      ecto = put_in(ecto[key][:type], true_branch[:type] || :string)

      put_validation(ecto, key, fn changeset ->
        validate_conditional_field(changeset, key, condition, true_branch, else_branch)
      end)
    end

    def parse_peri({key, {:dependent, field, condition, type}}, ecto) when is_atom(field) do
      ecto = put_in(ecto[key][:depend], field)
      ecto = put_in(ecto[key][:condition], condition)
      type_ecto = parse_single_type(type)
      ecto = put_in(ecto[key][:type], type_ecto[:type])

      ecto =
        if type_ecto[:nested] do
          put_in(ecto[key][:nested], type_ecto[:nested])
        else
          ecto
        end

      put_validation(ecto, key, fn changeset ->
        dep_field_value = get_field(changeset, field)
        current_value = get_field(changeset, key)

        case condition.(current_value, dep_field_value) do
          :ok ->
            changeset

          {:error, message, context} ->
            add_error(changeset, key, message, context)
        end
      end)
    end

    def parse_peri({key, {:dependent, callback}}, ecto) when is_function(callback, 1) do
      ecto = put_in(ecto[key][:type], :any)

      put_validation(ecto, key, fn changeset ->
        validate_dependent_callback_field(changeset, key, callback)
      end)
    end

    def parse_peri({key, {:dependent, {mod, fun}}}, ecto) when is_atom(mod) and is_atom(fun) do
      callback = fn data -> apply(mod, fun, [data]) end
      parse_peri({key, {:dependent, callback}}, ecto)
    end

    def parse_peri({key, {:dependent, {mod, fun, args}}}, ecto)
        when is_atom(mod) and is_atom(fun) and is_list(args) do
      callback = fn data -> apply(mod, fun, [data | args]) end
      parse_peri({key, {:dependent, callback}}, ecto)
    end

    def parse_peri({key, {:custom, callback}}, ecto) when is_function(callback, 1) do
      ecto = put_in(ecto[key][:type], :any)

      put_validation(ecto, key, fn changeset ->
        value = get_field(changeset, key)

        if is_nil(value) do
          changeset
        else
          case callback.(value) do
            :ok ->
              changeset

            {:ok, _} ->
              changeset

            {:error, message, context} ->
              context = if is_list(context), do: context, else: []
              add_error(changeset, key, message, context)
          end
        end
      end)
    end

    def parse_peri({key, {:custom, {mod, fun}}}, ecto) when is_atom(mod) and is_atom(fun) do
      callback = fn value -> apply(mod, fun, [value]) end
      parse_peri({key, {:custom, callback}}, ecto)
    end

    def parse_peri({key, {:custom, {mod, fun, args}}}, ecto)
        when is_atom(mod) and is_atom(fun) and is_list(args) do
      callback = fn value -> apply(mod, fun, [value | args]) end
      parse_peri({key, {:custom, callback}}, ecto)
    end

    def parse_peri({key, type}, _ecto) do
      type = inspect(type, pretty: true)
      raise Peri.Error, message: "Ecto doesn't support `#{type}` type for #{key}"
    end

    # Helper function to validate either type
    defp validate_either_type(changeset, key, _fst, _snd, _ecto) do
      validate_change(changeset, key, fn ^key, _value ->
        []
      end)
    end

    defp validate_conditional_field(changeset, key, condition, true_branch, else_branch) do
      data = apply_changes(changeset)

      if condition.(data) do
        apply_conditional_validation(changeset, key, true_branch)
      else
        apply_conditional_validation(changeset, key, else_branch)
      end
    end

    defp validate_dependent_callback_field(changeset, key, callback) do
      data = apply_changes(changeset)

      case callback.(data) do
        {:ok, nil} ->
          changeset

        {:ok, schema_def} ->
          validate_with_dynamic_schema(changeset, key, schema_def)

        {:error, error_msg, context} ->
          context = if is_list(context), do: context, else: []
          add_error(changeset, key, error_msg, context)
      end
    end

    defp validate_with_dynamic_schema(changeset, key, schema_def) do
      case Peri.validate_schema(schema_def) do
        {:ok, valid_schema} ->
          parsed_schema = parse_single_type(valid_schema)
          apply_dependent_validation(changeset, key, parsed_schema)

        {:error, errors} ->
          Enum.reduce(errors, changeset, fn error, acc ->
            add_error(acc, key, "Invalid schema: #{inspect(error)}")
          end)
      end
    end

    defp put_validation(ecto, key, validation) do
      update_in(ecto[key][:validations], &[validation | &1])
    end

    defp validate_tuple(changeset, key, types) do
      validate_change(changeset, key, fn ^key, val ->
        case Peri.validate({:tuple, types}, val) do
          {:ok, _} ->
            []

          {:error, errors} when is_list(errors) ->
            [{key, "is invalid"}]

          {:error, msg} when is_binary(msg) ->
            [{key, msg}]

          {:error, _} ->
            [{key, "is invalid"}]
        end
      end)
    end

    defp embed_one(key) do
      {:embed, Embed.init(field: key, cardinality: :one, related: nil)}
    end

    defp embed_many(key) do
      {:embed, Embed.init(field: key, cardinality: :many, related: nil)}
    end

    defp parse_single_type(schema_def) do
      result = %{
        type: nil,
        required: nil,
        default: nil,
        validations: [],
        nested: nil
      }

      cond do
        is_nil(schema_def) ->
          put_in(result[:type], :string)

        is_map(schema_def) ->
          result = put_in(result[:nested], parse(schema_def))
          put_in(result[:type], embed_one("embeddable"))

        is_atom(schema_def) and schema_def in @raw_types ->
          put_in(result[:type], Type.from(schema_def))

        match?({:required, _}, schema_def) ->
          {_, inner_type} = schema_def
          inner_result = parse_single_type(inner_type)
          result = put_in(result[:required], true)
          result = put_in(result[:type], inner_result[:type])

          if inner_result[:nested] do
            put_in(result[:nested], inner_result[:nested])
          else
            result
          end

        match?({:list, _}, schema_def) ->
          {_, inner_type} = schema_def

          if is_map(inner_type) do
            result = put_in(result[:nested], parse(inner_type))
            put_in(result[:type], embed_many("embeddable"))
          else
            put_in(result[:type], {:array, Type.from(inner_type)})
          end

        match?({:tuple, _}, schema_def) ->
          {_, elements} = schema_def
          put_in(result[:type], Type.from({:tuple, elements}))

        match?({:enum, _}, schema_def) ->
          put_in(result[:type], Type.from(schema_def))

        match?({:either, _}, schema_def) ->
          put_in(result[:type], Type.from(schema_def))

        match?({:oneof, _}, schema_def) ->
          put_in(result[:type], Type.from(schema_def))

        match?({_, {:default, _}}, schema_def) ->
          {inner_type, {:default, default_value}} = schema_def
          result = put_in(result[:default], default_value)
          inner_result = parse_single_type(inner_type)
          result = put_in(result[:type], inner_result[:type])

          if inner_result[:nested] do
            put_in(result[:nested], inner_result[:nested])
          else
            result
          end

        match?({:string, {:regex, _}}, schema_def) or
          match?({:string, {:eq, _}}, schema_def) or
          match?({:string, {:min, _}}, schema_def) or
            match?({:string, {:max, _}}, schema_def) ->
          put_in(result[:type], :string)

        match?({:integer, _}, schema_def) ->
          put_in(result[:type], :integer)

        match?({:float, _}, schema_def) ->
          put_in(result[:type], :float)

        true ->
          put_in(result[:type], :string)
      end
    end

    defp apply_conditional_validation(changeset, _key, nil_or_false_ecto)
         when is_nil(nil_or_false_ecto) or nil_or_false_ecto == false do
      changeset
    end

    defp apply_conditional_validation(changeset, key, ecto_def) do
      changeset =
        if ecto_def[:required] do
          validate_required(changeset, [key])
        else
          changeset
        end

      Enum.reduce(ecto_def[:validations] || [], changeset, fn validation, acc ->
        validation.(acc)
      end)
    end

    defp apply_dependent_validation(changeset, key, parsed_schema) do
      changeset =
        if parsed_schema[:required] do
          validate_required(changeset, [key])
        else
          changeset
        end

      if parsed_schema[:nested] do
        current_value = get_field(changeset, key)

        if is_nil(current_value) do
          changeset
        else
          nested_changeset = cast({%{}, %{}}, current_value, Map.keys(parsed_schema[:nested]))

          nested_changeset =
            Enum.reduce(parsed_schema[:nested], nested_changeset, fn {nested_key, nested_def},
                                                                     acc ->
              if nested_def[:required] do
                validate_required(acc, [nested_key])
              else
                acc
              end
            end)

          nested_changeset =
            Enum.reduce(parsed_schema[:nested], nested_changeset, fn {_nested_key, nested_def},
                                                                     acc ->
              Enum.reduce(nested_def[:validations] || [], acc, fn validation, inner_acc ->
                validation.(inner_acc)
              end)
            end)

          if not nested_changeset.valid? do
            Enum.reduce(nested_changeset.errors, changeset, fn {field, {msg, opts}}, acc ->
              add_error(acc, key, "Invalid nested data: #{field} #{msg}", opts)
            end)
          else
            changeset
          end
        end
      else
        Enum.reduce(parsed_schema[:validations] || [], changeset, fn validation, acc ->
          validation.(acc)
        end)
      end
    end
  end
end
