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

    def parse_peri({key, type}, ecto) when is_map(type) do
      ecto = put_in(ecto[key][:nested], parse(type))
      put_in(ecto[key][:type], embed_one(key))
    end

    def parse_peri({key, {:tuple, types}}, ecto) when is_list(types) do
      ecto = put_in(ecto[key][:type], Type.from({:tuple, types}))

      put_validation(ecto, key, fn changeset ->
        validate_tuple(changeset, key, types)
      end)
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
      put_in(ecto[key][:type], Type.from({:either, {fst, snd}}))
    end

    def parse_peri({key, {:oneof, types}}, ecto) when is_list(types) do
      if Enum.any?(types, &is_map/1) do
        # nested = Enum.filter(types, &is_map/1)
        raise "unimplemented"
      else
        put_in(ecto[key][:type], Type.from({:oneof, types}))
      end
    end

    # needs the either or oneof implementation first
    def parse_peri({_key, {:cond, _condition, _true_type, _else_type}}, _ecto) do
      raise "unimplemented"
    end

    def parse_peri({key, type}, _ecto) do
      type = inspect(type, pretty: true)
      raise Peri.Error, message: "Ecto doesn't support `#{type}` type for #{key}"
    end

    defp put_validation(ecto, key, validation) do
      update_in(ecto[key][:validations], &[validation | &1])
    end

    defp validate_tuple(changeset, key, types) do
      validate_change(changeset, key, fn ^key, val ->
        case Peri.validate({:tuple, types}, val) do
          {:ok, _} -> []
          {:error, msg} -> [{key, msg}]
        end
      end)
    end

    defp embed_one(key) do
      {:embed, Embed.init(field: key, cardinality: :one, related: nil)}
    end

    defp embed_many(key) do
      {:embed, Embed.init(field: key, cardinality: :many, related: nil)}
    end
  end
end
