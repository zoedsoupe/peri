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
end
