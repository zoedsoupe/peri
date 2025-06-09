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
    @tag :complex_validation_rules
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

    test "validates tuple type" do
      schema = %{
        coordinates: {:tuple, [:float, :float]}
      }

      valid_attrs = %{coordinates: {10.5, 20.5}}
      invalid_attrs = %{coordinates: {10.5, "invalid"}}

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert get_field(valid_changeset, :coordinates) == {10.5, 20.5}
      assert %{coordinates: ["is invalid"]} = errors_on(invalid_changeset)
    end

    @tag :tuple_map
    test "validates tuple with nested map" do
      schema = %{
        user_data: {:tuple, [:string, %{age: :integer, active: :boolean}]}
      }

      valid_attrs = %{user_data: {"john", %{age: 30, active: true}}}
      invalid_attrs = %{user_data: {"john", %{age: "invalid", active: true}}}

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert get_field(valid_changeset, :user_data) == {"john", %{age: 30, active: true}}
    end

    test "validates either type" do
      schema = %{
        value: {:either, {:string, :integer}}
      }

      valid_string_attrs = %{value: "text"}
      valid_integer_attrs = %{value: 42}
      invalid_attrs = %{value: true}

      valid_string_changeset = Peri.to_changeset!(schema, valid_string_attrs)
      valid_integer_changeset = Peri.to_changeset!(schema, valid_integer_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_string_changeset)
      assert is_changeset(valid_integer_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_string_changeset.valid?
      assert valid_integer_changeset.valid?
      refute invalid_changeset.valid?

      assert get_change(valid_string_changeset, :value) == "text"
      assert get_change(valid_integer_changeset, :value) == 42
      assert %{value: ["is invalid"]} = errors_on(invalid_changeset)
    end

    test "validates either type with simple types" do
      schema = %{
        value: {:either, {:string, :integer}}
      }

      valid_string_attrs = %{value: "text"}
      valid_int_attrs = %{value: 42}
      invalid_attrs = %{value: true}

      valid_string_changeset = Peri.to_changeset!(schema, valid_string_attrs)
      valid_int_changeset = Peri.to_changeset!(schema, valid_int_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_string_changeset)
      assert is_changeset(valid_int_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_string_changeset.valid?
      assert valid_int_changeset.valid?
      refute invalid_changeset.valid?
    end

    test "validates either type with single nested field map" do
      schema = %{
        user_data: {:either, {:string, %{name: :string}}}
      }

      valid_string_attrs = %{user_data: "N/A"}
      valid_map_attrs = %{user_data: %{name: "John"}}
      invalid_attrs = %{user_data: 42}

      valid_string_changeset = Peri.to_changeset!(schema, valid_string_attrs)
      valid_map_changeset = Peri.to_changeset!(schema, valid_map_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_string_changeset)
      assert is_changeset(valid_map_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_string_changeset.valid?
      assert valid_map_changeset.valid?
      refute invalid_changeset.valid?
    end

    test "validates either type with nested map" do
      schema = %{
        user_data: {:either, {:string, %{name: :string, age: :integer}}}
      }

      valid_string_attrs = %{user_data: "N/A"}
      valid_map_attrs = %{user_data: %{name: "John", age: 30}}
      invalid_attrs = %{user_data: 42}

      valid_string_changeset = Peri.to_changeset!(schema, valid_string_attrs)
      valid_map_changeset = Peri.to_changeset!(schema, valid_map_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_string_changeset)
      assert is_changeset(valid_map_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_string_changeset.valid?
      assert valid_map_changeset.valid?
      refute invalid_changeset.valid?
    end

    test "validates oneof type" do
      schema = %{
        value: {:oneof, [:string, :integer, :boolean]}
      }

      valid_string_attrs = %{value: "text"}
      valid_integer_attrs = %{value: 42}
      valid_boolean_attrs = %{value: true}
      invalid_attrs = %{value: %{}}

      valid_string_changeset = Peri.to_changeset!(schema, valid_string_attrs)
      valid_integer_changeset = Peri.to_changeset!(schema, valid_integer_attrs)
      valid_boolean_changeset = Peri.to_changeset!(schema, valid_boolean_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_string_changeset)
      assert is_changeset(valid_integer_changeset)
      assert is_changeset(valid_boolean_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_string_changeset.valid?
      assert valid_integer_changeset.valid?
      assert valid_boolean_changeset.valid?
      refute invalid_changeset.valid?
    end

    test "validates oneof type with nested map" do
      schema = %{
        user_data: {:oneof, [:string, %{name: :string, age: :integer}, :boolean]}
      }

      valid_string_attrs = %{user_data: "N/A"}
      valid_map_attrs = %{user_data: %{name: "John", age: 30}}
      valid_boolean_attrs = %{user_data: false}
      invalid_attrs = %{user_data: 42}

      valid_string_changeset = Peri.to_changeset!(schema, valid_string_attrs)
      valid_map_changeset = Peri.to_changeset!(schema, valid_map_attrs)
      valid_boolean_changeset = Peri.to_changeset!(schema, valid_boolean_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_string_changeset)
      assert is_changeset(valid_map_changeset)
      assert is_changeset(valid_boolean_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_string_changeset.valid?
      assert valid_map_changeset.valid?
      assert valid_boolean_changeset.valid?
      refute invalid_changeset.valid?
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

    test "validates conditional fields" do
      schema = %{
        provide_details: {:required, :boolean},
        details: {:cond, & &1.provide_details, {:required, %{email: {:required, :string}}}, nil}
      }

      valid_with_details = %{
        provide_details: true,
        details: %{email: "john@example.com"}
      }

      valid_without_details = %{
        provide_details: false
      }

      invalid_attrs = %{
        provide_details: true,
        details: %{}
      }

      valid_with_details_changeset = Peri.to_changeset!(schema, valid_with_details)
      valid_without_details_changeset = Peri.to_changeset!(schema, valid_without_details)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_with_details_changeset)
      assert is_changeset(valid_without_details_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_with_details_changeset.valid?
      assert valid_without_details_changeset.valid?
      refute invalid_changeset.valid?

      assert get_change(valid_with_details_changeset, :details)
      refute get_change(valid_without_details_changeset, :details)
    end

    test "validates dependent field (field condition)" do
      schema = %{
        password: {:required, :string},
        password_confirmation:
          {:dependent, :password,
           fn val, password ->
             if val == password, do: :ok, else: {:error, "must match password", []}
           end, :string}
      }

      valid_attrs = %{
        password: "Secret123",
        password_confirmation: "Secret123"
      }

      invalid_attrs = %{
        password: "Secret123",
        password_confirmation: "Different"
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert %{password_confirmation: ["must match password"]} = errors_on(invalid_changeset)
    end

    test "validates dependent field (callback)" do
      schema = %{
        provide_email: {:required, :boolean},
        provide_country: {:required, :boolean},
        details:
          {:dependent,
           fn %{provide_email: pe, provide_country: pc} = _data ->
             case {pe, pc} do
               {true, true} ->
                 {:ok, {:required, %{email: {:required, :string}, country: {:required, :string}}}}

               {true, false} ->
                 {:ok, {:required, %{email: {:required, :string}}}}

               {false, true} ->
                 {:ok, {:required, %{country: {:required, :string}}}}

               {false, false} ->
                 {:ok, nil}
             end
           end}
      }

      valid_both = %{
        provide_email: true,
        provide_country: true,
        details: %{email: "john@example.com", country: "USA"}
      }

      valid_email_only = %{
        provide_email: true,
        provide_country: false,
        details: %{email: "john@example.com"}
      }

      valid_country_only = %{
        provide_email: false,
        provide_country: true,
        details: %{country: "USA"}
      }

      valid_none = %{
        provide_email: false,
        provide_country: false
      }

      invalid_attrs = %{
        provide_email: true,
        provide_country: true,
        details: %{email: "john@example.com"}
      }

      valid_both_changeset = Peri.to_changeset!(schema, valid_both)
      valid_email_only_changeset = Peri.to_changeset!(schema, valid_email_only)
      valid_country_only_changeset = Peri.to_changeset!(schema, valid_country_only)
      valid_none_changeset = Peri.to_changeset!(schema, valid_none)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_both_changeset)
      assert is_changeset(valid_email_only_changeset)
      assert is_changeset(valid_country_only_changeset)
      assert is_changeset(valid_none_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_both_changeset.valid?
      assert valid_email_only_changeset.valid?
      assert valid_country_only_changeset.valid?
      assert valid_none_changeset.valid?
      refute invalid_changeset.valid?
    end

    test "validates custom validation" do
      defmodule CustomValidator do
        def validate_age(age) when is_integer(age) and age >= 18 and age <= 100, do: :ok
        def validate_age(_), do: {:error, "must be between 18 and 100", []}

        def validate_email(email) when is_binary(email) do
          if String.contains?(email, "@"), do: :ok, else: {:error, "invalid email format", []}
        end

        def validate_email(_), do: {:error, "invalid email format", []}
      end

      schema = %{
        age: {:custom, &CustomValidator.validate_age/1},
        email: {:custom, {CustomValidator, :validate_email}}
      }

      valid_attrs = %{
        age: 30,
        email: "john@example.com"
      }

      invalid_attrs = %{
        age: 15,
        email: "invalid-email"
      }

      valid_changeset = Peri.to_changeset!(schema, valid_attrs)
      invalid_changeset = Peri.to_changeset!(schema, invalid_attrs)

      assert is_changeset(valid_changeset)
      assert is_changeset(invalid_changeset)

      assert valid_changeset.valid?
      refute invalid_changeset.valid?

      assert %{
               age: ["must be between 18 and 100"],
               email: ["invalid email format"]
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
