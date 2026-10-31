defmodule Peri.ListConstraintsTest do
  use ExUnit.Case, async: true

  describe "validate_schema/1 — list constraint shape" do
    test "accepts :list as an untyped list schema" do
      assert {:ok, :list} = Peri.validate_schema(:list)
      assert {:ok, [1]} = Peri.validate(:list, [1])
      assert {:error, _} = Peri.validate(:list, :not_a_list)
    end

    test "accepts :min, :max, :unique" do
      assert {:ok, _} = Peri.validate_schema({:list, :integer, [min: 1, max: 5, unique: true]})
    end

    test "rejects unknown constraint" do
      assert {:error, _} = Peri.validate_schema({:list, :integer, [foo: 1]})
    end

    test "rejects non-keyword opts" do
      assert {:error, _} = Peri.validate_schema({:list, :integer, [:bogus]})
    end
  end

  describe "validate/2 — :list with constraints" do
    test ":min enforced" do
      schema = %{tags: {:list, :string, [min: 2]}}
      assert {:error, [err]} = Peri.validate(schema, %{tags: ["a"]})
      assert err.message =~ "at least 2"
      assert {:ok, _} = Peri.validate(schema, %{tags: ["a", "b"]})
    end

    test ":max enforced" do
      schema = %{tags: {:list, :string, [max: 2]}}
      assert {:error, [err]} = Peri.validate(schema, %{tags: ["a", "b", "c"]})
      assert err.message =~ "at most 2"
    end

    test ":unique enforced" do
      schema = %{tags: {:list, :string, [unique: true]}}
      assert {:error, [err]} = Peri.validate(schema, %{tags: ["a", "a"]})
      assert err.message =~ "unique"
      assert {:ok, _} = Peri.validate(schema, %{tags: ["a", "b"]})
    end

    test "still validates element types" do
      schema = %{nums: {:list, :integer, [min: 1]}}
      assert {:error, _} = Peri.validate(schema, %{nums: ["x"]})
    end
  end

  describe "validate/2 — :multiple_of" do
    test "integer multiple_of" do
      schema = %{n: {:integer, {:multiple_of, 3}}}
      assert {:ok, _} = Peri.validate(schema, %{n: 9})
      assert {:error, [err]} = Peri.validate(schema, %{n: 10})
      assert err.message =~ "multiple of"
    end

    test "float multiple_of" do
      schema = %{n: {:float, {:multiple_of, 0.5}}}
      assert {:ok, _} = Peri.validate(schema, %{n: 1.5})
      assert {:error, _} = Peri.validate(schema, %{n: 1.3})
    end

    test "schema rejects zero divisor" do
      assert {:error, _} = Peri.validate_schema({:integer, {:multiple_of, 0}})
    end

    test "works inside opts list" do
      schema = %{n: {:integer, [gte: 0, multiple_of: 5]}}
      assert {:ok, _} = Peri.validate(schema, %{n: 25})
      assert {:error, _} = Peri.validate(schema, %{n: 24})
    end
  end

  describe "to_json_schema/2 — encoder" do
    test "list constraints emit minItems/maxItems/uniqueItems" do
      assert Peri.to_json_schema({:list, :integer, [min: 1, max: 3, unique: true]}) == %{
               "type" => "array",
               "items" => %{"type" => "integer"},
               "minItems" => 1,
               "maxItems" => 3,
               "uniqueItems" => true
             }
    end

    test "multipleOf emitted for numerics" do
      assert Peri.to_json_schema({:integer, {:multiple_of, 5}}) == %{
               "type" => "integer",
               "multipleOf" => 5
             }

      assert Peri.to_json_schema({:float, {:multiple_of, 0.25}}) == %{
               "type" => "number",
               "multipleOf" => 0.25
             }
    end

    test "merges with other numeric opts" do
      json = Peri.to_json_schema({:integer, [gte: 0, multiple_of: 2]})
      assert json["type"] == "integer"
      assert json["minimum"] == 0
      assert json["multipleOf"] == 2
    end
  end

  describe "from_json_schema/1 — decoder" do
    test "decodes minItems/maxItems/uniqueItems" do
      json = %{
        "type" => "array",
        "items" => %{"type" => "string"},
        "minItems" => 1,
        "maxItems" => 4,
        "uniqueItems" => true
      }

      assert {:ok, {:list, :string, opts}} = Peri.from_json_schema(json)
      assert opts[:min] == 1
      assert opts[:max] == 4
      assert opts[:unique] == true
    end

    test "decodes multipleOf for integer values and integral floats only" do
      json = %{"type" => "integer", "multipleOf" => 5}

      integral_float =
        {:custom, {Peri.JSONSchema.Decoder, :validate_integral_float, [json]}}

      assert {:ok, {:either, {{:integer, {:multiple_of, 5}}, ^integral_float}} = schema} =
               Peri.from_json_schema(json)

      assert {:ok, 10} = Peri.validate(schema, 10)
      assert {:ok, 10.0} = Peri.validate(schema, 10.0)
      assert {:error, _} = Peri.validate(schema, 7)
      assert {:error, _} = Peri.validate(schema, 5.5)
    end

    test "plain array integer items accept integers and integral floats" do
      json = %{"type" => "array", "items" => %{"type" => "integer"}}
      assert {:ok, {:list, item_schema}} = Peri.from_json_schema(json)
      assert item_schema == decoded_integer_schema()
      assert {:ok, [1, 2.0]} = Peri.validate({:list, item_schema}, [1, 2.0])
      assert {:error, _} = Peri.validate({:list, item_schema}, [1, 2.5])
    end
  end

  describe "roundtrip" do
    test "list constraints roundtrip with integer item semantics" do
      peri = {:list, :integer, [min: 1, max: 3, unique: true]}
      json = Peri.to_json_schema(peri)

      assert {:ok, {:list, item_schema, [min: 1, max: 3, unique: true]} = decoded} =
               Peri.from_json_schema(json)

      assert item_schema == decoded_integer_schema()
      assert {:ok, [1, 2.0]} = Peri.validate(decoded, [1, 2.0])
      assert {:error, _} = Peri.validate(decoded, [1, 2.5])
    end

    test "multiple_of roundtrip preserves integer-valued float semantics" do
      peri = {:integer, {:multiple_of, 5}}
      json = Peri.to_json_schema(peri)

      assert {:ok, schema} = Peri.from_json_schema(json)
      assert schema == decoded_integer_schema(%{"type" => "integer", "multipleOf" => 5})
      assert {:ok, 10.0} = Peri.validate(schema, 10.0)
      assert {:error, _} = Peri.validate(schema, 10.5)
    end
  end

  defp decoded_integer_schema(json_schema \\ %{"type" => "integer"}) do
    integer_type =
      case Map.fetch(json_schema, "multipleOf") do
        {:ok, divisor} -> {:integer, {:multiple_of, divisor}}
        :error -> :integer
      end

    {:either,
     {integer_type, {:custom, {Peri.JSONSchema.Decoder, :validate_integral_float, [json_schema]}}}}
  end

  if Code.ensure_loaded?(StreamData) do
    describe "Generatable" do
      test "list with min/max generates within bounds" do
        schema = {:list, :integer, [min: 2, max: 4]}

        for list <- Enum.take(Peri.Generatable.gen(schema), 20) do
          assert length(list) >= 2
          assert length(list) <= 4
          assert Enum.all?(list, &is_integer/1)
        end
      end

      test "multiple_of generates valid integers" do
        schema = {:integer, {:multiple_of, 3}}

        for n <- Enum.take(Peri.Generatable.gen(schema), 20) do
          assert rem(n, 3) == 0
        end
      end

      test "float range generates floats within bounds" do
        schema = {:float, {:range, {1.0, 10.0}}}

        for n <- Enum.take(Peri.Generatable.gen(schema), 20) do
          assert is_float(n)
          assert n >= 1.0 and n <= 10.0
        end
      end

      test "unique list with min always passes validation" do
        schema = {:list, :integer, [min: 2, unique: true]}

        for list <- Enum.take(Peri.Generatable.gen(schema), 20) do
          assert length(list) >= 2
          assert list == Enum.uniq(list)
          assert {:ok, ^list} = Peri.validate(schema, list)
        end
      end
    end
  end
end
