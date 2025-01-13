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

  @behaviour Exception

  @type t :: %__MODULE__{
          message: String.t(),
          content: keyword,
          path: list(atom),
          key: atom | nil,
          errors: list(t()) | nil
        }

  @derive {Inspect, only: ~w(path key content message errors)a}
  defstruct [:path, :key, :content, :message, :errors, __exception__: true]

  @impl true
  def exception([%__MODULE__{} | _] = errors) when is_list(errors) do
    struct(__MODULE__, errors: errors)
  end

  def exception(%__MODULE__{} = err), do: exception(Map.from_struct(err))

  def exception(params) when is_map(params) or is_list(params) do
    struct!(__MODULE__, params)
  end

  @impl true
  def message(%__MODULE__{errors: nil, path: nil} = err), do: err.message

  def message(%__MODULE__{errors: nil} = err) do
    "#{inspect(err.path, pretty: true)} -> #{err.message}"
  end

  def message(%__MODULE__{errors: nested}) when is_list(nested) do
    nested
    |> Enum.map(&message/1)
    |> then(fn [x | xs] ->
      [x | Enum.map(xs, &(String.duplicate("\s", 16) <> &1))]
    end)
    |> Enum.join(",\n")
  end

  @doc """
  Creates a new parent error with nested errors.

  ## Parameters

    - `path` - A list representing the path to the invalid data.
    - `key` - The specific key or field that caused the error.
    - `errors` - A list of nested `Peri.Error` structs.

  ## Examples

      iex> Peri.Error.new_parent([:user], :age, [%Peri.Error{message: "Invalid age"}])
      %Peri.Error{
        path: [:user, :age],
        key: :age,
        errors: [%Peri.Error{message: "Invalid age"}]
      }
  """
  def new_parent(path, key, [%__MODULE__{} | _] = errors) when is_list(path) do
    %__MODULE__{path: path ++ [key], key: key, errors: errors}
  end

  @doc """
  Creates a new single error with a formatted message and context.

  ## Parameters

    - `message` - A string template for the error message.
    - `context` - A list of key-value pairs to replace in the message template.

  ## Examples

      iex> Peri.Error.new_single("Invalid value for %{field}", [field: "age"])
      %Peri.Error{
        message: "Invalid value for age",
        content: %{field: "age"}
      }
  """
  def new_single(message, context) do
    msg = format_error_message(message, context)
    content = Enum.into(context, %{})

    %__MODULE__{message: msg, content: content}
  end

  @doc """
  Creates a new child error with a path, key, message, and context.

  ## Parameters

    - `path` - A list representing the path to the invalid data.
    - `key` - The specific key or field that caused the error.
    - `message` - A string template for the error message.
    - `context` - A list of key-value pairs to replace in the message template.

  ## Examples

      iex> Peri.Error.new_child([:user], :age, "Invalid value for %{field}", [field: "age"])
      %Peri.Error{
        path: [:user, :age],
        key: :age,
        message: "Invalid value for age",
        content: %{field: "age"}
      }
  """
  def new_child(path, key, message, context) do
    msg = format_error_message(message, context)
    content = Enum.into(context, %{})

    %__MODULE__{path: path ++ [key], key: key, message: msg, content: content}
  end

  def update_error_paths(%Peri.Error{path: path, errors: nil} = error, new_path) do
    %Peri.Error{error | path: new_path ++ path}
  end

  def update_error_paths(%Peri.Error{path: path, errors: errors} = error, new_path) do
    updated_errors = Enum.map(errors, &update_error_paths(&1, new_path))
    %Peri.Error{error | path: new_path ++ path, errors: updated_errors}
  end

  def format_error_message(reason, context) when is_list(context) and is_binary(reason) do
    Enum.reduce(context, reason, fn {key, val}, acc ->
      String.replace(
        acc,
        "%{#{key}}",
        if(is_binary(val), do: val, else: inspect(val, pretty: true))
      )
    end)
  end

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
      content: transform_content(err.content),
      message: err.message,
      errors: transform_errors(err.errors)
    }
  end

  defp transform_content(content) do
    for {k, v} <- content do
      if is_tuple(v) do
        {k, transform_tuple(v)}
      else
        {k, v}
      end
    end
    |> Map.new()
  end

  defp transform_tuple(tuple) when is_tuple(tuple) do
    for el <- Tuple.to_list(tuple) do
      if is_tuple(el) do
        transform_tuple(el)
      else
        el
      end
    end
  end

  defp transform_errors(nil), do: nil

  defp transform_errors(errors) when is_list(errors) do
    Enum.map(errors, &error_to_map/1)
  end

  if Code.ensure_loaded?(:json) do
    def error_to_json(%Peri.Error{} = err) do
      err
      |> Peri.Error.error_to_map()
      |> transform_nil()
      |> :json.encode()
    end

    defp transform_nil(err) do
      for {k, v} <- err do
        cond do
          is_nil(v) -> {k, :null}
          is_map(v) -> {k, transform_nil(v)}
          true -> {k, v}
        end
      end
      |> Map.new()
    end
  end

  if Code.ensure_loaded?(Jason) do
    defimpl Jason.Encoder, for: __MODULE__ do
      def encode(%Peri.Error{} = err, opts) do
        err
        |> Peri.Error.error_to_map()
        |> Jason.Encode.map(opts)
      end
    end
  end
end
