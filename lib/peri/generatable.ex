if Code.ensure_loaded?(StreamData) do
  defmodule Peri.Generatable do
    @moduledoc """
    A module for generating sample data based on Peri schemas using StreamData.

    This module provides functions to generate various types of data, conforming to the schema definitions given in Peri. It leverages the StreamData library to create streams of random data that match the specified types and constraints.

    ## Examples

        iex> schema = %{
        ...>   name: :string,
        ...>   age: {:integer, {:gte, 18}},
        ...>   active: :boolean
        ...> }
        iex> Peri.Generatable.gen(schema)
        %StreamData{
          type: :fixed_map,
          data: %{name: StreamData.string(:alphanumeric), age: StreamData.filter(StreamData.integer(), &(&1 >= 18)), active: StreamData.boolean()}
        }

    """

    require Peri

    @doc """
    Generates a stream of data based on the given schema type.

    This function provides various clauses to handle different types and constraints defined in Peri schemas. It uses StreamData to generate streams of random data conforming to the specified types and constraints.

    ## Parameters

      - `schema`: The schema type to generate data for. It can be a simple type like `:integer`, `:string`, etc., or a complex type with constraints like `{:integer, {:gte, 18}}`.

    ## Returns

      - A StreamData generator stream for the specified schema type.

    ## Examples

        iex> Peri.Generatable.gen(:atom)
        %StreamData{type: :atom, data: ...}

        iex> Peri.Generatable.gen(:string)
        %StreamData{type: :string, data: ...}

        iex> Peri.Generatable.gen(:integer)
        %StreamData{type: :integer, data: ...}

        iex> Peri.Generatable.gen({:enum, [:admin, :user, :guest]})
        %StreamData{type: :one_of, data: ...}

        iex> Peri.Generatable.gen({:list, :integer})
        %StreamData{type: :list_of, data: ...}

        iex> Peri.Generatable.gen({:tuple, [:string, :integer]})
        %StreamData{type: :tuple, data: ...}

        iex> Peri.Generatable.gen({:integer, {:gt, 10}})
        %StreamData{type: :filter, data: ...}

        iex> Peri.Generatable.gen({:string, {:regex, ~r/^[a-z]+$/}})
        %StreamData{type: :filter, data: ...}

        iex> Peri.Generatable.gen({:either, {:integer, :string}})
        %StreamData{type: :one_of, data: ...}

        iex> Peri.Generatable.gen({:custom, {MyModule, :my_fun}})
        %StreamData{type: :filter, data: ...}

        iex> schema = %{name: :string, age: {:integer, {:gte, 18}}}
        iex> Peri.Generatable.gen(schema)
        %StreamData{type: :fixed_map, data: ...}

    """
    def gen(:atom), do: StreamData.atom(:alphanumeric)
    def gen(:atom!), do: gen(:atom)
    def gen(:any), do: StreamData.term()
    def gen(:string), do: StreamData.string(:alphanumeric)
    def gen(:integer), do: StreamData.integer()
    def gen(:float), do: StreamData.float()
    def gen(:boolean), do: StreamData.boolean()
    def gen(:map), do: StreamData.constant(%{})
    def gen(:pid), do: StreamData.constant(self())
    def gen(:list), do: StreamData.list_of(StreamData.term(), max_length: 5)
    def gen(:date), do: StreamData.date(min: ~D[1970-01-01], max: ~D[2100-12-31])

    def gen(:time) do
      StreamData.integer(0..86_399)
      |> StreamData.map(&Time.from_seconds_after_midnight/1)
    end

    def gen(:datetime) do
      gen(:date)
      |> StreamData.bind(fn date ->
        StreamData.map(gen(:time), &DateTime.new!(date, &1, "Etc/UTC"))
      end)
    end

    def gen(:naive_datetime) do
      gen(:date)
      |> StreamData.bind(fn date ->
        StreamData.map(gen(:time), &NaiveDateTime.new!(date, &1))
      end)
    end

    def gen(:duration), do: StreamData.constant(Duration.new!(second: 1))

    def gen({:literal, literal}), do: StreamData.constant(literal)

    def gen({:schema, type}), do: gen(type)

    def gen({:schema, schema, {:additional_keys, _value_type}}) when is_map(schema),
      do: gen(schema)

    def gen({:schema, type, opts}) when is_list(opts), do: gen(type)

    def gen({:dependent, _field, _condition, type}), do: gen(type)

    def gen({:dependent, _callback}) do
      raise ArgumentError,
            "cannot generate a dynamic dependent schema; use a fixed dependent type or a gen override"
    end

    def gen({:required, type}) do
      ensure_required_ref_is_generatable!(type)
      gen(type)
    end

    def gen({:required, type, opts}) when is_list(opts) do
      case Keyword.fetch(opts, :gen) do
        {:ok, override} ->
          apply_gen_override(override)

        :error ->
          ensure_required_ref_is_generatable!(type)
          gen(type)
      end
    end

    def gen({:meta, type, opts}) when is_list(opts) do
      case Keyword.fetch(opts, :gen) do
        {:ok, override} -> apply_gen_override(override)
        :error -> gen(type)
      end
    end

    @ref_gen_depth 5

    def gen({:multi, field, branches}) when is_atom(field) and is_map(branches) do
      branches
      |> Enum.map(fn {tag, branch} ->
        StreamData.bind(gen(branch), fn val ->
          StreamData.constant(merge_dispatch(val, field, tag))
        end)
      end)
      |> StreamData.one_of()
    end

    def gen({:ref, name}) when is_atom(name) do
      raise ArgumentError,
            "cannot generate data for unresolved local ref #{inspect(name)}; use {:ref, {Mod, #{inspect(name)}}}"
    end

    def gen({:ref, {mod, name}}) when is_atom(mod) and is_atom(name) do
      key = {:peri_ref_depth, mod, name}
      depth = Process.get(key, 0)

      if depth >= @ref_gen_depth do
        StreamData.constant(nil)
      else
        Process.put(key, depth + 1)

        try do
          gen(mod.get_schema(name))
        after
          if depth == 0, do: Process.delete(key), else: Process.put(key, depth)
        end
      end
    end

    def gen({:enum, choices}) do
      choices
      |> Enum.map(&StreamData.constant/1)
      |> StreamData.one_of()
    end

    def gen({:enum, choices, opts}) when is_list(opts) do
      case Keyword.fetch(opts, :gen) do
        {:ok, override} -> apply_gen_override(override)
        :error -> gen({:enum, choices})
      end
    end

    def gen({:integer, opts}) when is_list(opts) do
      case Keyword.fetch(opts, :gen) do
        {:ok, override} -> apply_gen_override(override)
        :error -> integer_constraints(opts)
      end
    end

    def gen({:string, opts}) when is_list(opts) do
      case Keyword.fetch(opts, :gen) do
        {:ok, override} -> apply_gen_override(override)
        :error -> string_constraints(opts)
      end
    end

    def gen({:list, type}) do
      type
      |> gen()
      |> StreamData.list_of()
    end

    def gen({:list, type, list_opts}) when is_list(list_opts) do
      sd_opts =
        Enum.flat_map(list_opts, fn
          {:min, n} -> [min_length: n]
          {:max, n} -> [max_length: n]
          _ -> []
        end)

      if Keyword.get(list_opts, :unique) == true do
        StreamData.uniq_list_of(gen(type), sd_opts)
      else
        StreamData.list_of(gen(type), sd_opts)
      end
    end

    def gen({:map, type}) do
      key_generator =
        StreamData.one_of([
          StreamData.atom(:alphanumeric),
          StreamData.string(:alphanumeric)
        ])

      value_generator = gen(type)

      StreamData.map_of(key_generator, value_generator)
    end

    def gen({:map, key_type, value_type}) do
      key_generator = gen(key_type)
      value_generator = gen(value_type)

      StreamData.map_of(key_generator, value_generator)
    end

    def gen({:tuple, types}) do
      types
      |> Enum.map(&gen/1)
      |> List.to_tuple()
      |> StreamData.tuple()
    end

    def gen({:integer, {:eq, eq}}), do: integer_constraints(eq: eq)

    def gen({type, {:eq, eq}}) when type in [:float] do
      StreamData.constant(eq)
    end

    def gen({type, {:neq, neq}}) when Peri.is_numeric_type(type) do
      stream = gen(type)
      StreamData.filter(stream, &(&1 != neq))
    end

    def gen({:integer, {:gt, gt}}), do: integer_constraints(gt: gt)

    def gen({type, {:gt, gt}}) when type == :float do
      stream = gen(type)
      StreamData.filter(stream, &(&1 > gt))
    end

    def gen({:integer, {:gte, gte}}), do: integer_constraints(gte: gte)

    def gen({type, {:gte, gte}}) when type == :float do
      stream = gen(type)
      StreamData.filter(stream, &(&1 >= gte))
    end

    def gen({:integer, {:lt, lt}}), do: integer_constraints(lt: lt)

    def gen({type, {:lt, lt}}) when type == :float do
      stream = gen(type)
      StreamData.filter(stream, &(&1 < lt))
    end

    def gen({:integer, {:lte, lte}}), do: integer_constraints(lte: lte)

    def gen({type, {:lte, lte}}) when type == :float do
      stream = gen(type)
      StreamData.filter(stream, &(&1 <= lte))
    end

    def gen({:float, {:range, {min, max}}}) do
      StreamData.float(min: min / 1, max: max / 1)
    end

    def gen({:integer, {:range, {min, max}}}), do: integer_constraints(range: {min, max})

    def gen({type, {:multiple_of, n}}) when Peri.is_numeric_type(type) do
      gen(type) |> apply_multiple_of(n)
    end

    def gen({:string, {:regex, regex}}) do
      stream = gen(:string)
      StreamData.filter(stream, &Regex.match?(regex, &1))
    end

    def gen({:string, {:eq, eq}}) do
      StreamData.constant(eq)
    end

    def gen({:string, {:min, min}}) do
      string_constraints(min: min)
    end

    def gen({:string, {:max, max}}) do
      string_constraints(max: max)
    end

    def gen({type, {:default, _}}), do: gen(type)

    def gen({type, {:transform, mapper}}) do
      stream = gen(type)

      case mapper do
        fun when is_function(fun, 1) ->
          map_valid_transform(stream, type, fun)

        fun when is_function(fun, 2) ->
          stream

        {mod, fun} when is_atom(mod) and is_atom(fun) ->
          map_mfa_transform(stream, type, mod, fun, [])

        {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
          map_mfa_transform(stream, type, mod, fun, args)
      end
    end

    def gen({:coerce, target}), do: gen(target)
    def gen({:coerce, target, opts}) when is_list(opts), do: gen(target)
    def gen({:coerce, _source, target}), do: gen(target)
    def gen({:coerce, _source, target, _opts}), do: gen(target)
    def gen({type, {:encode, _}}), do: gen(type)

    def gen({type, opts}) when Peri.is_type_with_multiple_options(type) and is_list(opts) do
      case Keyword.fetch(opts, :gen) do
        {:ok, override} ->
          apply_gen_override(override)

        :error ->
          opts
          |> Keyword.delete(:error)
          |> Enum.reduce(gen(type), &apply_constraint_filter(&2, type, &1))
      end
    end

    def gen({:either, {type_1, type_2}}) do
      stream_1 = gen(type_1)
      stream_2 = gen(type_2)
      StreamData.one_of([stream_1, stream_2])
    end

    def gen({:oneof, types}) do
      types
      |> Enum.map(&gen/1)
      |> StreamData.one_of()
    end

    def gen({:custom, {mod, fun}}) do
      StreamData.filter(StreamData.term(), fn val ->
        case apply(mod, fun, [val]) do
          :ok -> true
          {:ok, _} -> true
          {:error, _reason, _info} -> false
        end
      end)
    end

    def gen({:custom, {mod, fun, args}}) do
      StreamData.filter(StreamData.term(), fn val ->
        case apply(mod, fun, [val | args]) do
          :ok -> true
          {:ok, _} -> true
          {:error, _reason, _info} -> false
        end
      end)
    end

    def gen({:custom, cb}) do
      StreamData.filter(StreamData.term(), fn val ->
        case cb.(val) do
          :ok -> true
          {:ok, _} -> true
          {:error, _reason, _info} -> false
        end
      end)
    end

    def gen(schema) when is_map(schema) do
      generators = Enum.map(schema, fn {key, type} -> {key, gen(type)} end)
      StreamData.fixed_map(generators)
    end

    def gen(schema) when is_list(schema) do
      generators = Enum.map(schema, fn {key, type} -> {key, gen(type)} end)
      StreamData.fixed_map(generators)
    end

    defp merge_dispatch(val, field, tag) when is_map(val), do: Map.put(val, field, tag)
    defp merge_dispatch(val, field, tag) when is_list(val), do: Keyword.put(val, field, tag)
    defp merge_dispatch(val, _field, _tag), do: val

    defp integer_constraints(opts) do
      opts = Keyword.drop(opts, [:error, :gen])
      stream = integer_generator_for_bounds(opts)

      Enum.reduce(opts, stream, fn
        {:multiple_of, value}, acc ->
          StreamData.filter(acc, &integer_multiple_of?(&1, value))

        constraint, acc ->
          apply_constraint_filter(acc, :integer, constraint)
      end)
    end

    defp integer_generator_for_bounds(opts) do
      case Keyword.fetch(opts, :eq) do
        {:ok, exact} -> integer_exact_generator(exact)
        :error -> integer_bounded_generator(opts)
      end
    end

    defp integer_exact_generator(exact) do
      case exact_integer(exact) do
        {:ok, value} -> StreamData.constant(value)
        :error -> StreamData.filter(StreamData.integer(), fn _ -> false end)
      end
    end

    defp integer_bounded_generator(opts) do
      {min, max} = integer_bounds(opts)

      case Keyword.fetch(opts, :multiple_of) do
        {:ok, value} when is_integer(value) and value != 0 ->
          integer_multiples_generator(min, max, abs(value))

        _other ->
          integer_range_generator(min, max)
      end
    end

    defp integer_multiples_generator(min, max, step) when min <= max do
      first = ceil_div(min, step)
      last = Integer.floor_div(max, step)

      if first <= last do
        StreamData.integer(first..last)
        |> StreamData.map(&(&1 * step))
      else
        StreamData.filter(StreamData.integer(), fn _ -> false end)
      end
    end

    defp integer_multiples_generator(_min, _max, _step),
      do: StreamData.filter(StreamData.integer(), fn _ -> false end)

    defp ceil_div(dividend, divisor) when is_integer(dividend) and is_integer(divisor) do
      if divisor == 0, do: raise(ArithmeticError)

      case {div(dividend, divisor), rem(dividend, divisor)} do
        {quotient, 0} ->
          quotient

        {quotient, _} when (dividend > 0 and divisor > 0) or (dividend < 0 and divisor < 0) ->
          quotient + 1

        {quotient, _remainder} ->
          quotient
      end
    end

    defp integer_multiple_of?(_value, 0), do: false

    defp integer_multiple_of?(value, multiple) do
      quotient = value / multiple
      abs(quotient - Float.round(quotient)) < 1.0e-9
    end

    defp integer_range_generator(min, max) when min <= max,
      do: StreamData.integer(min..max)

    defp integer_range_generator(_min, _max),
      do: StreamData.filter(StreamData.integer(), fn _ -> false end)

    defp integer_bounds(opts) do
      min =
        Enum.reduce(opts, nil, fn
          {:gt, value}, current -> max_bound(current, floor(value) + 1)
          {:gte, value}, current -> max_bound(current, ceil(value))
          {:range, {value, _}}, current -> max_bound(current, ceil(value))
          _, current -> current
        end)

      max =
        Enum.reduce(opts, nil, fn
          {:lt, value}, current -> min_bound(current, ceil(value) - 1)
          {:lte, value}, current -> min_bound(current, floor(value))
          {:range, {_, value}}, current -> min_bound(current, floor(value))
          _, current -> current
        end)

      cond do
        is_nil(min) and is_nil(max) -> {-100, 100}
        is_nil(min) -> {max - 100, max}
        is_nil(max) -> {min, min + 100}
        true -> {min, max}
      end
    end

    defp exact_integer(value) when is_integer(value), do: {:ok, value}

    defp exact_integer(value) when is_float(value) do
      if value == trunc(value), do: {:ok, trunc(value)}, else: :error
    end

    defp exact_integer(_value), do: :error

    defp max_bound(nil, value), do: value
    defp max_bound(current, value), do: max(current, value)
    defp min_bound(nil, value), do: value
    defp min_bound(current, value), do: min(current, value)

    defp string_constraints(opts) do
      opts = Keyword.drop(opts, [:error, :gen])
      stream = string_generator_for_bounds(opts)

      Enum.reduce(opts, stream, fn constraint, acc ->
        apply_constraint_filter(acc, :string, constraint)
      end)
    end

    defp string_generator_for_bounds(opts) do
      case Keyword.fetch(opts, :eq) do
        {:ok, value} ->
          StreamData.constant(value)

        :error ->
          min = opts |> Keyword.get(:min, 0) |> max(0)
          max = Keyword.get(opts, :max, min + 20)

          if is_integer(max) and max >= min do
            StreamData.string(:alphanumeric, min_length: min, max_length: max)
          else
            gen(:string)
          end
      end
    end

    defp ensure_required_ref_is_generatable!({:ref, {mod, name}})
         when is_atom(mod) and is_atom(name) do
      if Process.get({:peri_ref_depth, mod, name}, 0) >= @ref_gen_depth do
        raise ArgumentError,
              "cannot generate a required recursive ref #{inspect({mod, name})}; " <>
                "the schema has no finite required base case"
      end
    end

    defp ensure_required_ref_is_generatable!({:ref, name}) when is_atom(name), do: :ok

    defp ensure_required_ref_is_generatable!({:meta, type, _opts}),
      do: ensure_required_ref_is_generatable!(type)

    defp ensure_required_ref_is_generatable!(_type), do: :ok

    defp map_valid_transform(stream, type, fun) do
      StreamData.map(stream, fn value ->
        try do
          transformed = fun.(value)

          case Peri.validate(type, transformed) do
            {:ok, _validated} -> transformed
            {:error, _errors} -> value
          end
        rescue
          _error -> value
        end
      end)
    end

    defp map_mfa_transform(stream, type, mod, fun, args) do
      Code.ensure_loaded?(mod)
      unary_arity = length(args) + 1

      if function_exported?(mod, fun, unary_arity) do
        map_valid_transform(stream, type, fn value -> apply(mod, fun, [value | args]) end)
      else
        stream
      end
    end

    defp apply_gen_override({mod, fun, args})
         when is_atom(mod) and is_atom(fun) and is_list(args),
         do: apply(mod, fun, args)

    defp apply_gen_override({mod, fun}) when is_atom(mod) and is_atom(fun),
      do: apply(mod, fun, [])

    defp apply_gen_override(fun) when is_function(fun, 0), do: fun.()

    defp apply_gen_override(other) do
      raise ArgumentError,
            "invalid :gen override; expected MFA tuple, {mod, fun}, or 0-arity function, got: " <>
              inspect(other)
    end

    defp apply_constraint_filter(stream, _type, {:eq, v}),
      do: StreamData.filter(stream, &(&1 == v))

    defp apply_constraint_filter(stream, _type, {:neq, v}),
      do: StreamData.filter(stream, &(&1 != v))

    defp apply_constraint_filter(stream, _type, {:gt, v}),
      do: StreamData.filter(stream, &(&1 > v))

    defp apply_constraint_filter(stream, _type, {:gte, v}),
      do: StreamData.filter(stream, &(&1 >= v))

    defp apply_constraint_filter(stream, _type, {:lt, v}),
      do: StreamData.filter(stream, &(&1 < v))

    defp apply_constraint_filter(stream, _type, {:lte, v}),
      do: StreamData.filter(stream, &(&1 <= v))

    defp apply_constraint_filter(stream, type, {:multiple_of, n})
         when type in [:integer, :float] do
      apply_multiple_of(stream, n)
    end

    defp apply_constraint_filter(stream, _type, {:range, {min, max}}),
      do: StreamData.filter(stream, &(&1 >= min and &1 <= max))

    defp apply_constraint_filter(stream, :string, {:regex, regex}),
      do: StreamData.filter(stream, &Regex.match?(regex, &1))

    defp apply_constraint_filter(stream, :string, {:min, min}),
      do: StreamData.filter(stream, &(String.length(&1) >= min))

    defp apply_constraint_filter(stream, :string, {:max, max}),
      do: StreamData.filter(stream, &(String.length(&1) <= max))

    defp apply_constraint_filter(stream, _type, _opt), do: stream

    defp apply_multiple_of(stream, 0),
      do: StreamData.filter(stream, fn _ -> false end)

    defp apply_multiple_of(stream, n) when is_integer(n) do
      StreamData.map(stream, fn
        val when is_integer(val) -> val - rem(val, n)
        val when is_float(val) -> Float.round(val / n) * n
      end)
    end

    defp apply_multiple_of(stream, n) when is_float(n) do
      StreamData.map(stream, fn val -> Float.round(val / n) * n end)
    end
  end
end
