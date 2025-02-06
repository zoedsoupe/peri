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

  describe "enum types validation" do
    test "validates string enum values" do
      schema = %{
        status: {:enum, ["active", "inactive", "pending"]}
      }

      valid_attrs = %{status: "active"}
      invalid_attrs = %{status: "unknown"}

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(invalid_changeset)
    end

    test "validates atom enum values" do
      schema = %{
        role: {:enum, [:admin, :user, :guest]}
      }

      valid_attrs = %{role: :admin}
      invalid_attrs = %{role: :superuser}

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?
      assert %{role: ["is invalid"]} = errors_on(invalid_changeset)
    end
  end

  describe "list type validation" do
    test "validates list of primitive values" do
      schema = %{
        tags: {:list, :string},
        scores: {:list, :integer}
      }

      valid_attrs = %{
        tags: ["elixir", "ecto"],
        scores: [85, 90, 95]
      }

      invalid_attrs = %{
        tags: ["elixir", 123],
        scores: [85, :hello, 95]
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?
      assert get_change(valid_changeset, :tags) == ["elixir", "ecto"]
      assert get_change(valid_changeset, :scores) == [85, 90, 95]
      assert %{tags: ["is invalid"], scores: ["is invalid"]} = errors_on(invalid_changeset)
    end

    test "validates list of maps" do
      schema = %{
        addresses:
          {:list,
           %{
             street: {:required, :string},
             number: {:required, :integer},
             complement: :string
           }}
      }

      valid_attrs = %{
        addresses: [
          %{street: "Main St", number: 123},
          %{street: "Second St", number: 456, complement: "Apt 4B"}
        ]
      }

      invalid_attrs = %{
        addresses: [
          %{street: "Main St"},
          %{street: "Second St", number: :hello}
        ]
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert %{addresses: addresses_errors} = errors_on(invalid_changeset)

      assert [
               %{number: ["can't be blank"]},
               %{number: ["is invalid"]}
             ] = addresses_errors
    end
  end

  describe "custom type validation" do
    test "validates PID type" do
      schema = %{process: :pid}
      pid = self()

      valid_attrs = %{process: pid}
      invalid_attrs = %{process: "not_a_pid"}

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?
      assert get_change(valid_changeset, :process) == pid
      assert %{process: ["is invalid"]} = errors_on(invalid_changeset)
    end
  end

  describe "complex validation rules" do
    test "combines multiple string validations" do
      schema = %{
        password: {:string, {:regex, ~r/^(?=.*[A-Z])(?=.*[0-9]).{8,}$/}},
        confirm_password: {:string, {:eq, "Secret123"}}
      }

      valid_attrs = %{
        password: "Secret123",
        confirm_password: "Secret123"
      }

      invalid_attrs = %{
        password: "weak",
        confirm_password: "different"
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert %{
               password: ["has invalid format"],
               confirm_password: ["should be equal to literal Secret123"]
             } = errors_on(invalid_changeset)
    end

    test "validates date and time fields" do
      schema = %{
        date: :date,
        time: :time,
        datetime: :datetime,
        naive_datetime: :naive_datetime
      }

      valid_attrs = %{
        date: ~D[2024-02-05],
        time: ~T[10:30:00],
        datetime: DateTime.from_naive!(~N[2024-02-05 10:30:00], "Etc/UTC"),
        naive_datetime: ~N[2024-02-05 10:30:00]
      }

      invalid_attrs = %{
        date: "invalid",
        time: "invalid",
        datetime: "invalid",
        naive_datetime: "invalid"
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)
      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert %{
               date: ["is invalid"],
               time: ["is invalid"],
               datetime: ["is invalid"],
               naive_datetime: ["is invalid"]
             } = errors_on(invalid_changeset)
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
