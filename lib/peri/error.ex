defmodule Peri.Error do
  @moduledoc """
  Defines the structure and functions for handling validation errors in the Peri schema validation library.

  The `Peri.Error` module encapsulates information about validation errors that occur during schema validation. Each error contains details about the path to the invalid data, the type of error, and any nested errors for complex or deeply nested schemas.

  ## Attributes

  - `:message` - A human-readable message describing the error.
  - `:content` - Additional information about the error, such as expected and actual values.
  - `:path` - A list representing the path to the invalid data within the structure being validated.
  - `:key` - The specific key or field that caused the error.
  - `:errors` - A list of nested `Peri.Error` structs for detailed information about nested validation errors.

  ## Example

      iex> error = %Peri.Error{
      ...>   message: "Validation failed",
      ...>   content: %{expected: :string, actual: :integer},
      ...>   path: [:user, :age],
      ...>   key: :age,
      ...>   errors: [
      ...>     %Peri.Error{
      ...>       message: "Expected type string, got integer",
      ...>       content: nil,
      ...>       path: [:user, :age],
      ...>       key: :age,
      ...>       errors: nil
      ...>     }
      ...>   ]
      ...> }
      %Peri.Error{
        message: "Validation failed",
        content: %{expected: :string, actual: :integer},
        path: [:user, :age],
        key: :age,
        errors: [
          %Peri.Error{
            message: "Expected type string, got integer",
            content: nil,
            path: [:user, :age],
            key: :age,
            errors: nil
          }
        ]
      }

  ## Functions

  - `error_to_map/1` - Converts a `Peri.Error` struct to a map, including nested errors.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          content: keyword,
          path: list(atom),
          key: atom | nil,
          errors: list(t()) | nil
        }

  @derive {Inspect, only: ~w(path key content message errors)a}
  defstruct [:path, :key, :content, :message, :errors]

  @doc """
  Recursively converts a `Peri.Error` struct into a map.

  ## Parameters

    - `error` - A `Peri.Error` struct to be transformed.

  ## Examples

      iex> error = %Peri.Error{
      ...>   message: "Validation failed",
      ...>   content: %{expected: :string, actual: :integer},
      ...>   path: [:user, :age],
      ...>   key: :age,
      ...>   errors: [
      ...>     %Peri.Error{
      ...>       message: "Expected type string, got integer",
      ...>       content: nil,
      ...>       path: [:user, :age],
      ...>       key: :age,
      ...>       errors: nil
      ...>     }
      ...>   ]
      ...> }
      iex> Peri.Error.error_to_map(error)
      %{
        message: "Validation failed",
        content: %{expected: :string, actual: :integer},
        path: [:user, :age],
        key: :age,
        errors: [
          %{
            message: "Expected type string, got integer",
            content: nil,
            path: [:user, :age],
            key: :age,
            errors: nil
          }
        ]
      }

  """
  def error_to_map(%Peri.Error{} = err) do
    %{
      path: err.path,
      key: err.key,
      content: err.content,
      message: err.message,
      errors: transform_errors(err.errors)
    }
  end

  defp transform_errors(nil), do: nil

  defp transform_errors(errors) when is_list(errors) do
    Enum.map(errors, &error_to_map/1)
  end
end
