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
    def gen(:string), do: StreamData.string(:alphanumeric)
    def gen(:integer), do: StreamData.integer()
    def gen(:float), do: StreamData.float()
    def gen(:boolean), do: StreamData.boolean()

    def gen({:literal, literal}), do: StreamData.constant(literal)

    def gen({:required, type}), do: gen(type)

    def gen({:enum, choices}) do
      choices
      |> Enum.map(&StreamData.constant/1)
      |> StreamData.one_of()
    end

    def gen({:list, type}) do
      type
      |> gen()
      |> StreamData.list_of()
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

    def gen({type, {:eq, eq}}) when Peri.is_numeric_type(type) do
      StreamData.constant(eq)
    end

    def gen({type, {:neq, neq}}) when Peri.is_numeric_type(type) do
      stream = gen(type)
      StreamData.filter(stream, &(&1 != neq))
    end

    def gen({type, {:gt, gt}}) when Peri.is_numeric_type(type) do
      stream = gen(type)
      StreamData.filter(stream, &(&1 > gt))
    end

    def gen({type, {:gte, gte}}) when Peri.is_numeric_type(type) do
      stream = gen(type)
      StreamData.filter(stream, &(&1 >= gte))
    end

    def gen({type, {:lt, lt}}) when Peri.is_numeric_type(type) do
      stream = gen(type)
      StreamData.filter(stream, &(&1 < lt))
    end

    def gen({type, {:lte, lte}}) when Peri.is_numeric_type(type) do
      stream = gen(type)
      StreamData.filter(stream, &(&1 <= lte))
    end

    def gen({type, {:range, {min, max}}}) when Peri.is_numeric_type(type) do
      stream = gen(type)
      StreamData.filter(stream, &(&1 in min..max))
    end

    def gen({:string, {:regex, regex}}) do
      stream = gen(:string)
      StreamData.filter(stream, &Regex.match?(regex, &1))
    end

    def gen({:string, {:eq, eq}}) do
      StreamData.constant(eq)
    end

    def gen({:string, {:min, min}}) do
      stream = gen(:string)
      StreamData.filter(stream, &(String.length(&1) >= min))
    end

    def gen({:string, {:max, max}}) do
      stream = gen(:string)
      StreamData.filter(stream, &(String.length(&1) <= max))
    end

    def gen({type, {:default, _}}), do: gen(type)
    def gen({type, {:dependent, _, _, _}}), do: gen(type)

    def gen({type, {:transform, mapper}}) do
      stream = gen(type)
      StreamData.map(stream, mapper)
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

    def gen(schema) when Peri.is_enumerable(schema) do
      for {k, v} <- schema do
        stream = gen(v)
        {k, stream}
      end
      |> StreamData.fixed_map()
    end
  end
end
