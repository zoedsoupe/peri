if Code.ensure_loaded?(StreamData) do
  defmodule Peri.Generatable do
    require Peri

    def gen(:atom), do: StreamData.atom(:alphanumeric)
    def gen(:string), do: StreamData.string(:alphanumeric)
    def gen(:integer), do: StreamData.integer()
    def gen(:float), do: StreamData.float()
    def gen(:boolean), do: StreamData.boolean()

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
      Stream.filter(StreamData.term(), fn val ->
        case apply(mod, fun, [val]) do
          :ok -> true
          {:ok, _} -> true
          {:error, _reason, _info} -> false
        end
      end)
    end

    def gen({:custom, {mod, fun, args}}) do
      Stream.filter(StreamData.term(), fn val ->
        case apply(mod, fun, [val | args]) do
          :ok -> true
          {:ok, _} -> true
          {:error, _reason, _info} -> false
        end
      end)
    end

    def gen({:custom, cb}) do
      Stream.filter(StreamData.term(), fn val ->
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
