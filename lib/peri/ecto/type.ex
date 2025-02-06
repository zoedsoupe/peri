defmodule Peri.Ecto.Type do
  @moduledoc "Responsible to convert between Peri <> Ecto types definitions"

  alias Ecto.ParameterizedType
  alias Peri.Ecto.Type.PID

  @spec from(Peri.schema_def()) :: term
  def from(:pid), do: PID
  def from(:datetime), do: :utc_datetime

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
