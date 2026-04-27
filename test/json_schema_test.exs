defmodule Peri.JSONSchemaTest do
  use ExUnit.Case, async: true

  alias Peri.JSONSchema.Encoder.UnsupportedTypeError

  describe "to_json_schema/2 — basic types" do
    test "primitive types" do
      assert Peri.to_json_schema(:string) == %{"type" => "string"}
      assert Peri.to_json_schema(:integer) == %{"type" => "integer"}
      assert Peri.to_json_schema(:float) == %{"type" => "number"}
      assert Peri.to_json_schema(:boolean) == %{"type" => "boolean"}
      assert Peri.to_json_schema(:any) == %{}
      assert Peri.to_json_schema(nil) == %{"type" => "null"}
    end

    test "time types" do
      assert Peri.to_json_schema(:date) == %{"type" => "string", "format" => "date"}
      assert Peri.to_json_schema(:datetime) == %{"type" => "string", "format" => "date-time"}
    end

    test "literals and enums" do
      assert Peri.to_json_schema({:literal, :ok}) == %{"const" => :ok}
      assert Peri.to_json_schema({:enum, [:a, :b]}) == %{"enum" => [:a, :b]}
    end
  end

  describe "to_json_schema/2 — objects and required" do
    test "object with mixed required and optional" do
      schema = %{name: {:required, :string}, age: :integer}
      json = Peri.to_json_schema(schema)

      assert json["type"] == "object"
      assert json["properties"]["name"] == %{"type" => "string"}
      assert json["properties"]["age"] == %{"type" => "integer"}
      assert json["required"] == ["name"]
    end

    test "object with no required omits required key" do
      assert Peri.to_json_schema(%{name: :string}) ==
               %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
    end

    test "nested objects" do
      schema = %{user: %{name: {:required, :string}}}
      json = Peri.to_json_schema(schema)
      assert json["properties"]["user"]["type"] == "object"
      assert json["properties"]["user"]["required"] == ["name"]
    end
  end

  describe "to_json_schema/2 — collections" do
    test "list" do
      assert Peri.to_json_schema({:list, :integer}) ==
               %{"type" => "array", "items" => %{"type" => "integer"}}
    end

    test "map with value type" do
      assert Peri.to_json_schema({:map, :string}) ==
               %{"type" => "object", "additionalProperties" => %{"type" => "string"}}
    end

    test "tuple as fixed-length array" do
      assert Peri.to_json_schema({:tuple, [:string, :integer]}) ==
               %{
                 "type" => "array",
                 "items" => [%{"type" => "string"}, %{"type" => "integer"}],
                 "minItems" => 2,
                 "maxItems" => 2
               }
    end
  end

  describe "to_json_schema/2 — constraints" do
    test "integer constraints" do
      assert Peri.to_json_schema({:integer, gte: 0}) ==
               %{"type" => "integer", "minimum" => 0}

      assert Peri.to_json_schema({:integer, gt: 0}) ==
               %{"type" => "integer", "exclusiveMinimum" => 0}

      assert Peri.to_json_schema({:integer, [gte: 0, lte: 100]}) ==
               %{"type" => "integer", "minimum" => 0, "maximum" => 100}
    end

    test "string regex" do
      assert Peri.to_json_schema({:string, {:regex, ~r/^foo/}}) ==
               %{"type" => "string", "pattern" => "^foo"}
    end

    test "string min/max" do
      assert Peri.to_json_schema({:string, [min: 3, max: 10]}) ==
               %{"type" => "string", "minLength" => 3, "maxLength" => 10}
    end
  end

  describe "to_json_schema/2 — unions" do
    test "either → oneOf" do
      assert Peri.to_json_schema({:either, {:string, :integer}}) ==
               %{"oneOf" => [%{"type" => "string"}, %{"type" => "integer"}]}
    end

    test "oneof → oneOf" do
      assert Peri.to_json_schema({:oneof, [:string, :integer, :boolean]}) ==
               %{
                 "oneOf" => [
                   %{"type" => "string"},
                   %{"type" => "integer"},
                   %{"type" => "boolean"}
                 ]
               }
    end
  end

  describe "to_json_schema/2 — defaults and meta" do
    test "default surfaces under \"default\"" do
      assert Peri.to_json_schema({:string, {:default, "x"}}) ==
               %{"type" => "string", "default" => "x"}
    end

    test "meta wrapper attaches title/description/examples/deprecated" do
      schema = %{
        email:
          {:meta, {:required, :string},
           title: "Email", description: "Login", example: "a@b.io", deprecated: false}
      }

      json = Peri.to_json_schema(schema)
      prop = json["properties"]["email"]
      assert prop["type"] == "string"
      assert prop["title"] == "Email"
      assert prop["description"] == "Login"
      assert prop["examples"] == ["a@b.io"]
      assert prop["deprecated"] == false
      assert json["required"] == ["email"]
    end
  end

  describe "to_json_schema/2 — :on_unsupported" do
    test ":omit (default) emits empty schema for custom" do
      schema = %{f: {:custom, fn _ -> :ok end}}
      assert Peri.to_json_schema(schema)["properties"]["f"] == %{}
    end

    test ":raise raises on dependent" do
      schema = %{f: {:dependent, fn _ -> {:ok, :string} end}}

      assert_raise UnsupportedTypeError, fn ->
        Peri.to_json_schema(schema, on_unsupported: :raise)
      end
    end
  end

  describe "from_json_schema/1" do
    test "object with required" do
      json = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      assert {:ok, schema} = Peri.from_json_schema(json)
      assert schema[:name] == {:required, :string}
      assert schema[:age] == :integer
    end

    test "primitives" do
      assert {:ok, :string} = Peri.from_json_schema(%{"type" => "string"})
      assert {:ok, :integer} = Peri.from_json_schema(%{"type" => "integer"})
      assert {:ok, :boolean} = Peri.from_json_schema(%{"type" => "boolean"})
      assert {:ok, {:literal, nil}} = Peri.from_json_schema(%{"type" => "null"})
    end

    test "const → literal" do
      assert {:ok, {:literal, "x"}} = Peri.from_json_schema(%{"const" => "x"})
    end

    test "enum" do
      assert {:ok, {:enum, [1, 2, 3]}} = Peri.from_json_schema(%{"enum" => [1, 2, 3]})
    end

    test "array" do
      assert {:ok, {:list, :string}} =
               Peri.from_json_schema(%{"type" => "array", "items" => %{"type" => "string"}})
    end

    test "oneOf with two → either" do
      json = %{"oneOf" => [%{"type" => "string"}, %{"type" => "integer"}]}
      assert {:ok, {:either, {:string, :integer}}} = Peri.from_json_schema(json)
    end

    test "integer minimum → gte" do
      json = %{"type" => "integer", "minimum" => 0}
      assert {:ok, {:integer, {:gte, 0}}} = Peri.from_json_schema(json)
    end

    test "string pattern → regex" do
      json = %{"type" => "string", "pattern" => "^foo"}
      assert {:ok, {:string, {:regex, %Regex{}}}} = Peri.from_json_schema(json)
    end

    test "invalid regex pattern is dropped, not raised" do
      json = %{"type" => "string", "pattern" => "["}
      assert {:ok, :string} = Peri.from_json_schema(json)
    end

    test "non-existing atom keys fall back to string keys" do
      key = "this_atom_does_not_exist_#{System.unique_integer([:positive])}"

      json = %{
        "type" => "object",
        "properties" => %{key => %{"type" => "string"}}
      }

      assert {:ok, schema} = Peri.from_json_schema(json)
      assert schema[key] == :string
    end
  end

  describe "round-trip" do
    test "primitives" do
      for type <- [:string, :integer, :float, :boolean] do
        assert {:ok, ^type} = type |> Peri.to_json_schema() |> Peri.from_json_schema()
      end
    end

    test "object with required" do
      schema = %{name: {:required, :string}, age: :integer}
      json = Peri.to_json_schema(schema)
      assert {:ok, decoded} = Peri.from_json_schema(json)
      assert decoded[:name] == {:required, :string}
      assert decoded[:age] == :integer
    end

    test "list of strings" do
      assert {:ok, {:list, :string}} =
               {:list, :string} |> Peri.to_json_schema() |> Peri.from_json_schema()
    end

    test "integer with gte" do
      assert {:ok, {:integer, {:gte, 0}}} =
               {:integer, gte: 0} |> Peri.to_json_schema() |> Peri.from_json_schema()
    end
  end
end
