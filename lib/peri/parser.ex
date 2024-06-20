defmodule Peri.Parser do
  @moduledoc """
  The `Peri.Parser` module is responsible for managing the state during schema validation. 
  It centralizes functions to handle updating data, adding errors, and managing the path within 
  the data structure being validated.

  ## Struct
  The `Peri.Parser` struct has the following fields:

  - `:data` - The current state of the data being validated.
  - `:errors` - A list of errors encountered during validation.
  - `:path` - The current path within the data structure being validated.
  """

  defstruct [:data, :errors, :path]

  @doc """
  Initializes a new `Peri.Parser` struct with the given data.

  ## Parameters
  - `data` - The initial data to be validated.

  ## Examples

      iex> Peri.Parser.new(%{name: "Alice"})
      %Peri.Parser{data: %{name: "Alice"}, errors: [], path: []}
  """
  def new(data) do
    %__MODULE__{data: data, errors: [], path: []}
  end

  @doc """
  Updates the data in the parser state at the given key with the specified value.

  ## Parameters
  - `state` - The current `Peri.Parser` state.
  - `key` - The key to update in the data.
  - `val` - The value to set at the specified key.

  ## Examples

      iex> state = Peri.Parser.new(%{name: "Alice"})
      iex> Peri.Parser.update_data(state, :age, 30)
      %Peri.Parser{data: %{name: "Alice", age: 30}, errors: [], path: []}
  """
  def update_data(%__MODULE__{} = state, key, val) do
    %{state | data: put_in(state.data[key], val)}
  end

  @doc """
  Adds an error to the parser state's list of errors.

  ## Parameters
  - `state` - The current `Peri.Parser` state.
  - `err` - The `%Peri.Error{}` struct representing the error to add.

  ## Examples

      iex> state = Peri.Parser.new(%{name: "Alice"})
      iex> error = %Peri.Error{path: [:name], message: "is required", content: []}
      iex> Peri.Parser.add_error(state, error)
      %Peri.Parser{data: %{name: "Alice"}, errors: [%Peri.Error{path: [:name], message: "is required", content: []}], path: []}
  """
  def add_error(%__MODULE__{} = state, %Peri.Error{} = err) do
    %{state | errors: [err | state.errors]}
  end
end
