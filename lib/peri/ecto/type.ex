if Code.ensure_loaded?(Ecto) do
  defmodule Peri.Ecto.Type do
    @moduledoc "Responsible to convert between Peri <> Ecto types definitions"

    alias Ecto.ParameterizedType

    @spec from(Peri.schema_def()) :: term
    def from(:any), do: __MODULE__.Any
    def from(:pid), do: __MODULE__.PID
    def from(:atom), do: __MODULE__.Atom
    def from(:datetime), do: :utc_datetime
    def from({:oneof, types}), do: ParameterizedType.init(__MODULE__.OneOf, values: types)

    def from({:either, {fst, snd}}),
      do: ParameterizedType.init(__MODULE__.Either, values: {fst, snd})

    def from({:tuple, types}), do: ParameterizedType.init(__MODULE__.Tuple, elements: types)

    def from({:list, inner}), do: {:array, from(inner)}

    def from({:enum, choices}) do
      cond do
        Enum.all?(choices, &is_binary/1) ->
          choices = Enum.map(choices, &String.to_atom/1)
          ParameterizedType.init(Ecto.Enum, values: choices)

        Enum.all?(choices, &is_atom/1) ->
          ParameterizedType.init(Ecto.Enum, values: choices)

        true ->
          raise Peri.Error, message: "Ecto.Enum only accepts strings and atoms"
      end
    end

    def from(type), do: type
  end

  defmodule Peri.Ecto.Type.PID do
    @moduledoc "Custom Ecto type for storing PIDs, use with caution"

    use Ecto.Type

    @impl true
    def type, do: :string

    @impl true
    def cast(pid) when is_pid(pid) do
      {:ok, pid}
    end

    def cast(_), do: :error

    @impl true
    def dump(pid) when is_pid(pid) do
      {:ok, :erlang.term_to_binary(pid)}
    end

    def dump(_), do: :error

    @impl true
    def load(pid) when is_binary(pid) do
      {:ok, :erlang.binary_to_term(pid)}
    end

    def load(_), do: :error
  end

  defmodule Peri.Ecto.Type.Atom do
    @moduledoc "Custom Ecto type for storing atoms as strings"

    use Ecto.Type

    @impl true
    def type, do: :string

    @impl true
    def cast(atom) when is_atom(atom), do: {:ok, atom}
    def cast(_), do: :error

    @impl true
    def dump(atom) when is_atom(atom) do
      {:ok, Atom.to_string(atom)}
    end

    def dump(_), do: :error

    @impl true
    def load(string) when is_binary(string) do
      {:ok, String.to_atom(string)}
    end

    def load(_), do: :error
  end

  defmodule Peri.Ecto.Type.Any do
    @moduledoc "Represents any type. Passes data to Cassandra as is."

    use Ecto.Type

    @impl true
    def type, do: :custom

    @impl true
    def cast(value), do: {:ok, value}

    @impl true
    def load(value), do: {:ok, value}

    @impl true
    def dump(value), do: {:ok, value}
  end

  defmodule Peri.Ecto.Type.Tuple do
    @moduledoc "Custom Ecto type for storing tuples with multiple types/elements"

    use Ecto.ParameterizedType

    @impl true
    def type(_), do: :map

    @impl true
    def init(elements: types) when is_list(types) do
      case Peri.validate_schema({:tuple, types}) do
        {:ok, {:tuple, types}} -> %{elements: Enum.map(types, &Peri.Ecto.Type.from/1)}
        {:error, message} -> raise Peri.Error, message
      end
    end

    @impl true
    def cast(tuple, %{elements: types}) when is_tuple(tuple) do
      with {_idx, values} <- cast_elements(tuple, types) do
        {:ok,
         values
         |> Enum.reverse()
         |> List.to_tuple()}
      end
    end

    def cast(_, _), do: :error

    defp cast_elements(tuple, types) do
      if tuple_size(tuple) != length(types) do
        :error
      else
        apply_elements_casting(tuple, types)
      end
    end

    defp apply_elements_casting(tuple, types) do
      Enum.reduce_while(types, {0, []}, fn type, {index, acc} ->
        case Ecto.Type.cast(type, elem(tuple, index)) do
          {:ok, value} -> {:cont, {index + 1, [value | acc]}}
          :error -> {:halt, :error}
        end
      end)
    end

    @impl true
    def dump(tuple, _dumper, _params) when is_tuple(tuple) do
      {:ok,
       tuple
       |> Tuple.to_list()
       |> Enum.with_index(fn el, idx -> {idx, el} end)
       |> Map.new()}
    end

    def dump(_, _, _), do: :error

    @impl true
    def load(tuple, _loader, _params) when is_map(tuple) do
      {:ok,
       tuple
       |> Map.to_list()
       |> Enum.sort_by(fn {idx, _} -> idx end)
       |> Enum.map(fn {_idx, value} -> value end)
       |> List.to_tuple()}
    end

    def load(_, _, _), do: :error
  end

  defmodule Peri.Ecto.Type.Either do
    @moduledoc "Custom Ecto type for storing either of two types"

    use Ecto.ParameterizedType

    import Peri.Ecto, only: [is_ecto_embed: 1]

    alias Peri.Ecto.Type

    require Peri.Ecto

    @impl true
    def type(_), do: :any

    @impl true
    def init(values: {fst, snd}) when is_ecto_embed(fst) do
      case Peri.validate_schema(snd) do
        {:ok, snd} -> %{values: {fst, Type.from(snd)}}
        {:error, message} -> raise Peri.Error, message
      end
    end

    def init(values: {fst, snd}) when is_ecto_embed(snd) do
      case Peri.validate_schema(fst) do
        {:ok, fst} -> %{values: {Type.from(fst), snd}}
        {:error, message} -> raise Peri.Error, message
      end
    end

    def init(values: {fst, snd}) do
      case Peri.validate_schema({:either, {fst, snd}}) do
        {:ok, {:either, {fst, snd}}} -> %{values: {Type.from(fst), Type.from(snd)}}
        {:error, message} -> raise Peri.Error, message
      end
    end

    @impl true
    # def cast(value, %{values: {fst, snd}}) when is_map(fst) do
    #   embed = {:embed, Embed.init(field: key, cardinality: :one, related: nil)}
    #   cast(value, %{values: {embed, snd}})
    # end

    # def cast(value, %{values: {fst, snd}}) when is_map(snd) do
    #   embed = {:embed, Embed.init(field: key, cardinality: :one, related: nil)}
    #   cast(value, %{values: {fst, snd}})
    # end

    def cast(value, %{values: {fst, snd}}) do
      with :error <- Ecto.Type.cast(fst, value) do
        Ecto.Type.cast(snd, value)
      end
    end

    @impl true
    def dump(value, _, %{values: {fst, snd}}) do
      with :error <- Ecto.Type.dump(fst, value) do
        Ecto.Type.dump(snd, value)
      end
    end

    @impl true
    def load(value, _, %{values: {fst, snd}}) do
      with :error <- Ecto.Type.load(fst, value) do
        Ecto.Type.load(snd, value)
      end
    end
  end

  defmodule Peri.Ecto.Type.OneOf do
    @moduledoc "Custom Ecto type for storing one of many types, aka sum types"

    use Ecto.ParameterizedType

    @impl true
    def type(_), do: :any

    @impl true
    def init(values: types) when is_list(types) do
      case Peri.validate_schema({:oneof, types}) do
        {:ok, {:oneof, types}} -> %{values: Enum.map(types, &Peri.Ecto.Type.from/1)}
        {:error, message} -> raise Peri.Error, message
      end
    end

    @impl true
    def cast(value, %{values: types}) do
      Enum.reduce_while(types, :error, fn type, _ ->
        case Ecto.Type.cast(type, value) do
          {:ok, value} -> {:halt, {:ok, value}}
          :error -> {:cont, :error}
        end
      end)
    end

    @impl true
    def dump(value, _, %{values: types}) do
      Enum.reduce_while(types, :error, fn type, _ ->
        case Ecto.Type.dump(type, value) do
          {:ok, value} -> {:halt, {:ok, value}}
          :error -> {:cont, :error}
        end
      end)
    end

    @impl true
    def load(value, _, %{values: types}) do
      Enum.reduce_while(types, :error, fn type, _ ->
        case Ecto.Type.load(type, value) do
          {:ok, value} -> {:halt, {:ok, value}}
          :error -> {:cont, :error}
        end
      end)
    end
  end
end
