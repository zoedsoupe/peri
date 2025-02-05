defmodule Peri.EctoTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  defguardp is_changeset(val) when is_struct(val, Ecto.Changeset)

  describe "primitive types validation" do
    test "validates and cast simple schema with string and integer" do
      schema = %{
        name: {:required, :string},
        age: :integer
      }

      attrs = %{
        name: "João",
        age: 25
      }

      changeset = Peri.to_changeset!(schema, attrs)
      assert is_changeset(changeset)
      assert changeset.valid?
      assert changeset.changes == attrs
    end

    test "validates and cast required fields" do
      schema = %{
        name: {:required, :string},
        age: :integer
      }

      attrs = %{age: 25}

      changeset = Peri.to_changeset!(schema, attrs)
      assert is_changeset(changeset)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "applies default values" do
      schema = %{
        name: {:string, {:default, "Anonymous"}},
        age: {:integer, {:default, 18}}
      }

      attrs = %{}

      changeset = Peri.to_changeset!(schema, attrs)
      assert changeset.valid?
      assert get_field(changeset, :name) == "Anonymous"
      assert get_field(changeset, :age) == 18
    end

    test "validates string format with regex" do
      schema = %{numeric: {:string, {:regex, ~r|\d+|}}}

      valid_attrs = %{numeric: "123"}
      invalid_attrs = %{numeric: "invalid"}

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?
      assert %{numeric: ["has invalid format"]} = errors_on(invalid_changeset)
    end
  end

  describe "nested schema validation" do
    test "validates nested schema" do
      schema = %{
        user: %{
          name: {:required, :string},
          profile: %{
            age: {:required, :integer},
            email: {:required, :string}
          }
        }
      }

      attrs = %{
        user: %{
          name: "Maria",
          profile: %{
            age: 30,
            email: "maria@example.com"
          }
        }
      }

      changeset = Peri.to_changeset!(schema, attrs)
      assert is_changeset(changeset)
      assert changeset.valid?
      assert {:ok, valid} = apply_action(changeset, :insert)
      assert valid == attrs
    end

    test "validates nested schema with missing required fields" do
      schema = %{
        user: %{
          name: {:required, :string},
          profile: %{
            age: {:required, :integer},
            email: {:required, :string}
          }
        }
      }

      attrs = %{
        user: %{
          name: "Maria",
          profile: %{
            age: 30
          }
        }
      }

      changeset = Peri.to_changeset!(schema, attrs)
      assert is_changeset(changeset)
      refute changeset.valid?

      assert %{user: %{profile: %{email: ["can't be blank"]}}} = errors_on(changeset)
    end

    test "validates nested schema with defaults" do
      schema = %{
        user: %{
          name: {:string, {:default, "Anonymous"}},
          profile: %{
            age: {:integer, {:default, 18}},
            email: {:required, :string}
          }
        }
      }

      attrs = %{
        user: %{
          profile: %{
            email: "anonymous@example.com"
          }
        }
      }

      changeset = Peri.to_changeset!(schema, attrs)
      assert is_changeset(changeset)
      assert changeset.valid?

      assert user = get_change(changeset, :user)
      assert get_field(user, :name) == "Anonymous"
      assert profile = get_change(user, :profile)
      assert get_field(profile, :age) == 18
      assert get_change(profile, :email) == "anonymous@example.com"
    end
  end

  describe "validation rules" do
    test "validates string length constraints" do
      schema = %{
        short_text: {:string, {:max, 5}},
        long_text: {:string, {:min, 10}}
      }

      valid_attrs = %{
        short_text: "hi",
        long_text: "hello world"
      }

      invalid_attrs = %{
        short_text: "too long",
        long_text: "short"
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert %{
               short_text: ["should be at most 5 character(s)"],
               long_text: ["should be at least 10 character(s)"]
             } =
               errors_on(invalid_changeset)
    end

    test "validates numeric constraints" do
      schema = %{
        age: {:integer, {:range, {18, 100}}},
        score: {:float, {:gte, 0.0}}
      }

      valid_attrs = %{
        age: 25,
        score: 85.5
      }

      invalid_attrs = %{
        age: 15,
        score: -1.0
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert %{
               age: ["must be greater than or equal to 18"],
               score: ["must be greater than or equal to 0.0"]
             } =
               errors_on(invalid_changeset)
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
