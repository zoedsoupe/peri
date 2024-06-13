defmodule PeriTest do
  use ExUnit.Case, async: true

  import Peri

  defschema(:simple, %{
    name: :string,
    age: :integer,
    email: {:required, :string}
  })

  defschema(:nested, %{
    user: %{
      name: :string,
      profile: %{
        age: {:required, :integer},
        email: {:required, :string}
      }
    }
  })

  defschema(:optional_fields, %{
    name: :string,
    age: {:required, :integer},
    email: {:required, :string},
    phone: :string
  })

  defschema(:invalid_nested_type, %{
    user: %{
      name: :string,
      profile: %{
        age: {:required, :integer},
        email: :string,
        address: %{
          street: :string,
          number: :integer
        }
      }
    }
  })

  describe "simple schema validation" do
    test "validates simple schema with valid data" do
      data = %{name: "John", age: 30, email: "john@example.com"}
      assert {:ok, ^data} = simple(data)
    end

    test "validates simple schema with missing required field" do
      data = %{name: "John", age: 30}
      assert {:error, errors} = simple(data)
      assert "is required" == errors[:email]
    end

    test "validates simple schema with invalid field type" do
      data = %{name: "John", age: "thirty", email: "john@example.com"}
      assert {:error, errors} = simple(data)
      assert "expected integer received thirty" == errors[:age]
    end
  end

  describe "nested schema validation" do
    test "validates nested schema with valid data" do
      data = %{user: %{name: "Jane", profile: %{age: 25, email: "jane@example.com"}}}
      assert {:ok, ^data} = nested(data)
    end

    test "validates nested schema with invalid data" do
      data = %{user: %{name: "Jane", profile: %{age: "twenty-five", email: "jane@example.com"}}}
      assert {:error, errors} = nested(data)
      assert "expected integer received twenty-five" == errors[:user][:profile][:age]
    end

    test "validates nested schema with missing required field" do
      data = %{user: %{name: "Jane", profile: %{age: 25}}}
      assert {:error, errors} = nested(data)
      assert "is required" == errors[:user][:profile][:email]
    end
  end

  describe "optional fields validation" do
    test "validates schema with optional fields" do
      data = %{name: "John", age: 30, email: "john@example.com"}
      assert {:ok, ^data} = optional_fields(data)

      data_with_optional = %{name: "John", age: 30, email: "john@example.com", phone: "123-456"}
      assert {:ok, ^data_with_optional} = optional_fields(data_with_optional)
    end

    test "validates schema with optional fields and invalid optional field type" do
      data = %{name: "John", age: 30, email: "john@example.com", phone: 123_456}
      assert {:error, errors} = optional_fields(data)
      assert "expected string received 123456" == errors[:phone]
    end
  end

  defschema(:list_example, %{
    tags: {:list, :string},
    scores: {:list, :integer}
  })

  defschema(:enum_example, %{
    role: {:enum, [:admin, :user, :guest]},
    status: {:enum, [:active, :inactive]}
  })

  describe "list validation" do
    test "validates list of strings with correct data" do
      data = %{tags: ["elixir", "programming"], scores: [1, 2, 3]}
      assert list_example(data) == {:ok, data}
    end

    test "validates list of strings with incorrect data type in list" do
      data = %{tags: ["elixir", 42], scores: [1, 2, 3]}
      assert list_example(data) == {:error, [tags: "expected string received 42"]}
    end

    test "validates list of integers with correct data" do
      data = %{tags: ["tag1", "tag2"], scores: [10, 20, 30]}
      assert list_example(data) == {:ok, data}
    end

    test "validates list of integers with incorrect data type in list" do
      data = %{tags: ["tag1", "tag2"], scores: [10, "twenty", 30]}
      assert list_example(data) == {:error, [scores: "expected integer received twenty"]}
    end

    test "handles empty lists correctly" do
      data = %{tags: [], scores: []}
      assert list_example(data) == {:ok, data}
    end

    test "handles missing lists correctly" do
      data = %{}
      assert list_example(data) == {:ok, data}
    end
  end

  describe "enum validation" do
    test "validates enum with correct data" do
      data = %{role: :admin, status: :active}
      assert enum_example(data) == {:ok, data}
    end

    test "validates enum with incorrect data" do
      data = %{role: :superuser, status: :active}

      assert enum_example(data) ==
               {:error, [role: "expected one of [:admin, :user, :guest] received :superuser"]}
    end

    test "validates enum with another incorrect data" do
      data = %{role: :admin, status: :pending}

      assert enum_example(data) ==
               {:error, [status: "expected one of [:active, :inactive] received :pending"]}
    end

    test "handles missing enum fields correctly" do
      data = %{}
      assert enum_example(data) == {:ok, data}
    end

    test "handles nil enum fields correctly" do
      data = %{role: nil, status: nil}
      assert enum_example(data) == {:ok, data}
    end
  end

  defschema(:list_of_maps_example, %{
    users:
      {:list,
       %{
         name: {:required, :string},
         age: {:required, :integer}
       }}
  })

  describe "list of maps validation" do
    test "validates list of maps with correct data" do
      data = %{users: [%{name: "Alice", age: 30}, %{name: "Bob", age: 25}]}
      assert list_of_maps_example(data) == {:ok, data}
    end

    test "validates list of maps with missing required fields" do
      data = %{users: [%{name: "Alice", age: 30}, %{age: 25}]}
      assert list_of_maps_example(data) == {:error, [users: [name: "is required"]]}
    end

    test "validates list of maps with incorrect field types" do
      data = %{users: [%{name: "Alice", age: "thirty"}, %{name: "Bob", age: 25}]}

      assert list_of_maps_example(data) ==
               {:error, [users: [age: "expected integer received thirty"]]}
    end

    test "validates list of maps with extra fields" do
      data = %{users: [%{name: "Alice", age: 30, extra: "field"}, %{name: "Bob", age: 25}]}
      assert list_of_maps_example(data) == {:ok, data}
    end

    test "handles empty list of maps" do
      data = %{users: []}
      assert list_of_maps_example(data) == {:ok, data}
    end

    test "handles missing list of maps" do
      data = %{}
      assert list_of_maps_example(data) == {:ok, data}
    end
  end

  defmodule CustomValidations do
    def positive?(val) when is_integer(val) and val > 0, do: :ok
    def positive?(_val), do: {:error, "must be positive"}

    def starts_with_a?(<<"a", _::binary>>), do: :ok
    def starts_with_a?(_val), do: {:error, "must start with 'a'"}
  end

  defschema(:custom_example, %{
    positive_number: {:custom, &CustomValidations.positive?/1},
    name: {:custom, {CustomValidations, :starts_with_a?}}
  })

  defschema(:tuple_example, %{
    coordinates: {:tuple, [:float, :float]}
  })

  describe "custom validation" do
    test "validates custom validation functions with correct data" do
      data = %{positive_number: 5, name: "alice"}
      assert custom_example(data) == {:ok, data}
    end

    test "validates custom validation functions with incorrect data" do
      data = %{positive_number: -5, name: "bob"}

      assert custom_example(data) ==
               {:error, [positive_number: "must be positive", name: "must start with 'a'"]}
    end

    test "handles missing custom validation fields correctly" do
      data = %{}
      assert custom_example(data) == {:ok, data}
    end
  end

  describe "tuple validation" do
    test "validates tuple with correct data" do
      data = %{coordinates: {10.5, 20.5}}
      assert tuple_example(data) == {:ok, data}
    end

    test "validates tuple with incorrect data type" do
      data = %{coordinates: {10.5, "20.5"}}

      assert tuple_example(data) ==
               {:error, [coordinates: "tuple element 1: expected float received 20.5"]}
    end

    test "validates tuple with incorrect size" do
      data = %{coordinates: {10.5}}

      assert tuple_example(data) ==
               {:error, [coordinates: "expected tuple of size 2 received {10.5}"]}
    end

    test "validates tuple with extra elements" do
      data = %{coordinates: {10.5, 20.5, 30.5}}

      assert tuple_example(data) ==
               {:error, [coordinates: "expected tuple of size 2 received {10.5, 20.5, 30.5}"]}
    end

    test "handles missing tuple correctly" do
      data = %{}
      assert tuple_example(data) == {:ok, data}
    end
  end

  defschema(:string_list, {:list, :string})
  defschema(:string_scores, %{name: :string, score: :float})
  defschema(:string_score_map, %{id: {:required, :integer}, scores: {:custom, &string_scores/1}})

  defschema(:recursive_schema, %{
    id: :integer,
    children: {:list, {:custom, &recursive_schema/1}}
  })

  describe "composable schema validation" do
    test "validates custom schema for list of strings" do
      data = ["hello", "world"]
      assert string_list(data) == {:ok, data}
    end

    test "validates custom schema for list of strings with invalid data" do
      data = ["hello", 123]
      assert string_list(data) == {:error, "expected string received 123"}
    end

    test "validates custom schema for map with nested schema" do
      data = %{id: 1, scores: %{name: "test", score: 95.5}}
      assert string_score_map(data) == {:ok, data}
    end

    test "validates custom schema for map with nested schema with invalid data" do
      data = %{id: 1, scores: %{name: "test", score: "high"}}
      assert string_score_map(data) == {:error, [scores: [score: "expected float received high"]]}
    end

    test "validates recursive schema with correct data" do
      data = %{
        id: 1,
        children: [%{id: 2, children: []}, %{id: 3, children: [%{id: 4, children: []}]}]
      }

      assert recursive_schema(data) == {:ok, data}
    end

    test "validates recursive schema with incorrect data" do
      data = %{id: 1, children: [%{id: 2, children: [%{id: "invalid", children: []}]}]}

      assert recursive_schema(data) ==
               {:error, [children: [children: [id: "expected integer received invalid"]]]}
    end

    test "validates schema with missing required fields" do
      data = %{scores: %{name: "test", score: 95.5}}
      assert string_score_map(data) == {:error, [id: "is required"]}
    end

    test "validates schema with extra fields" do
      data = %{id: 1, scores: %{name: "test", score: 95.5, extra: "field"}}
      assert string_score_map(data) == {:ok, data}
    end
  end

  defschema(:user, %{
    name: :string,
    age: :integer,
    email: {:required, :string}
  })

  defschema(:profile, %{
    user: {:custom, &user/1},
    bio: :string
  })

  describe "unknown keys" do
    test "drops unknown keys and validates correct data" do
      data = %{name: "John", age: 30, email: "john@example.com", extra_key: "value"}
      expected_data = %{name: "John", age: 30, email: "john@example.com"}
      assert user(data) == {:ok, expected_data}
    end

    test "drops unknown keys and handles missing required field" do
      data = %{name: "John", age: 30, extra_key: "value"}
      assert user(data) == {:error, email: "is required"}
    end

    test "drops multiple unknown keys and validates correct data" do
      data = %{
        name: "Jane",
        age: 25,
        email: "jane@example.com",
        extra_key1: "value1",
        extra_key2: "value2"
      }

      expected_data = %{name: "Jane", age: 25, email: "jane@example.com"}

      assert {:ok, ^expected_data} = user(data)
    end

    test "drops nested unknown keys and validates correct data" do
      data = %{
        user: %{name: "John", age: 30, email: "john@example.com", extra_key: "value"},
        bio: "Developer",
        extra_key2: "value2"
      }

      expected_data = %{
        user: %{name: "John", age: 30, email: "john@example.com"},
        bio: "Developer"
      }

      assert {:ok, ^expected_data} = profile(data)
    end

    test "drops nested unknown keys and handles missing required field" do
      data = %{
        user: %{name: "John", age: 30, extra_key: "value"},
        bio: "Developer",
        extra_key2: "value2"
      }

      assert profile(data) == {:error, [user: [email: "is required"]]}
    end
  end
end
