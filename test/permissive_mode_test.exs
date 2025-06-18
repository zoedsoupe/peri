defmodule Peri.PermissiveModeTest do
  use ExUnit.Case, async: true

  import Peri

  defschema(:user_strict, %{
    name: :string,
    email: :string
  })

  defschema(
    :user_permissive,
    %{
      name: :string,
      email: :string
    },
    mode: :permissive
  )

  describe "permissive mode" do
    test "filters extra fields by default (strict mode)" do
      schema = %{
        name: :string,
        age: :integer
      }

      data = %{name: "John", age: 30, extra: "field", another: 123}

      assert {:ok, result} = Peri.validate(schema, data)
      assert result == %{name: "John", age: 30}
      refute Map.has_key?(result, :extra)
      refute Map.has_key?(result, :another)
    end

    test "preserves extra fields when mode is permissive" do
      schema = %{
        name: :string,
        age: :integer
      }

      data = %{name: "John", age: 30, extra: "field", another: 123}

      assert {:ok, result} = Peri.validate(schema, data, mode: :permissive)
      assert result == %{name: "John", age: 30, extra: "field", another: 123}
    end

    test "permissive mode works with nested schemas" do
      schema = %{
        user: %{
          name: :string,
          email: :string
        }
      }

      data = %{
        user: %{name: "John", email: "john@example.com", role: "admin"},
        extra_field: "value"
      }

      assert {:ok, result} = Peri.validate(schema, data, mode: :permissive)

      assert result == %{
               user: %{name: "John", email: "john@example.com", role: "admin"},
               extra_field: "value"
             }
    end

    test "permissive mode works with lists containing nested schemas" do
      schema = %{
        users:
          {:list,
           %{
             name: :string,
             age: :integer
           }}
      }

      data = %{
        users: [
          %{name: "John", age: 30, role: "admin"},
          %{name: "Jane", age: 25, department: "IT"}
        ],
        total: 2
      }

      assert {:ok, result} = Peri.validate(schema, data, mode: :permissive)

      assert result == %{
               users: [
                 %{name: "John", age: 30, role: "admin"},
                 %{name: "Jane", age: 25, department: "IT"}
               ],
               total: 2
             }
    end

    test "permissive mode with string keys" do
      schema = %{
        "name" => :string,
        "age" => :integer
      }

      data = %{"name" => "John", "age" => 30, "extra" => "field"}

      assert {:ok, result} = Peri.validate(schema, data, mode: :permissive)
      assert result == %{"name" => "John", "age" => 30, "extra" => "field"}
    end

    test "defschema with mode option" do
      data = %{name: "John", email: "john@example.com", role: "admin"}

      assert {:ok, strict_result} = user_strict(data)
      assert strict_result == %{name: "John", email: "john@example.com"}

      assert {:ok, permissive_result} = user_permissive(data)
      assert permissive_result == %{name: "John", email: "john@example.com", role: "admin"}
    end

    test "invalid mode option raises error" do
      schema = %{name: :string}
      data = %{name: "John"}

      assert_raise ArgumentError, ~r/Invalid mode/, fn ->
        Peri.validate(schema, data, mode: :invalid)
      end
    end

    test "permissive mode still validates defined fields" do
      schema = %{
        name: {:required, :string},
        age: {:integer, {:gte, 18}}
      }

      valid_data = %{name: "John", age: 30, extra: "field"}
      assert {:ok, result} = Peri.validate(schema, valid_data, mode: :permissive)
      assert result == valid_data

      invalid_data = %{age: 30, extra: "field"}
      assert {:error, errors} = Peri.validate(schema, invalid_data, mode: :permissive)
      assert length(errors) == 1

      invalid_data2 = %{name: "John", age: 15, extra: "field"}
      assert {:error, errors} = Peri.validate(schema, invalid_data2, mode: :permissive)
      assert length(errors) == 1
    end

    test "permissive mode with deeply nested data" do
      schema = %{
        level1: %{
          level2: %{
            level3: %{
              value: :string
            }
          }
        }
      }

      data = %{
        level1: %{
          level2: %{
            level3: %{
              value: "deep",
              extra3: "field3"
            },
            extra2: "field2"
          },
          extra1: "field1"
        },
        extra0: "field0"
      }

      assert {:ok, result} = Peri.validate(schema, data, mode: :permissive)
      assert result == data
    end

    test "permissive mode with transformations" do
      schema = %{
        name: {:string, {:transform, &String.upcase/1}},
        status: :atom
      }

      data = %{name: "john", status: :active, role: "admin", score: 100}

      assert {:ok, result} = Peri.validate(schema, data, mode: :permissive)
      assert result == %{name: "JOHN", status: :active, role: "admin", score: 100}
    end
  end
end
