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

    test "meta :examples (plural) accepts a pre-built list" do
      schema = %{f: {:meta, :string, examples: ["a", "b"]}}
      assert Peri.to_json_schema(schema)["properties"]["f"]["examples"] == ["a", "b"]
    end

    test "meta surfaces JSON Schema vocab keys" do
      schema = %{
        token:
          {:meta, :string,
           format: "uuid",
           pattern: "^[0-9a-f-]+$",
           default: "00000000-0000-0000-0000-000000000000",
           read_only: true,
           write_only: false,
           content_encoding: "base64",
           content_media_type: "application/jwt"}
      }

      prop = Peri.to_json_schema(schema)["properties"]["token"]
      assert prop["format"] == "uuid"
      assert prop["pattern"] == "^[0-9a-f-]+$"
      assert prop["default"] == "00000000-0000-0000-0000-000000000000"
      assert prop["readOnly"] == true
      assert prop["writeOnly"] == false
      assert prop["contentEncoding"] == "base64"
      assert prop["contentMediaType"] == "application/jwt"
    end

    test "meta drops unknown keys" do
      schema = %{f: {:meta, :string, fromat: "uuid", custom_internal: 1}}
      prop = Peri.to_json_schema(schema)["properties"]["f"]
      assert prop == %{"type" => "string"}
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
      assert schema["name"] == {:required, :string}
      assert schema["age"] == {:either, {:integer, :float}}
    end

    test "primitives" do
      assert {:ok, :string} = Peri.from_json_schema(%{"type" => "string"})
      assert {:ok, :boolean} = Peri.from_json_schema(%{"type" => "boolean"})
      assert {:ok, {:literal, nil}} = Peri.from_json_schema(%{"type" => "null"})
    end

    test "numeric primitives map to either int|float per JSON Schema spec" do
      assert {:ok, {:either, {:integer, :float}}} =
               Peri.from_json_schema(%{"type" => "integer"})

      assert {:ok, {:either, {:integer, :float}}} =
               Peri.from_json_schema(%{"type" => "number"})
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
      json = %{"oneOf" => [%{"type" => "string"}, %{"type" => "boolean"}]}
      assert {:ok, {:either, {:string, :boolean}}} = Peri.from_json_schema(json)
    end

    test "integer minimum → gte applied to both branches" do
      json = %{"type" => "integer", "minimum" => 0}

      assert {:ok, {:either, {{:integer, {:gte, 0}}, {:float, {:gte, 0}}}}} =
               Peri.from_json_schema(json)
    end

    test "number minimum → gte applied to both branches" do
      json = %{"type" => "number", "minimum" => 0}

      assert {:ok, {:either, {{:integer, {:gte, 0}}, {:float, {:gte, 0}}}}} =
               Peri.from_json_schema(json)
    end

    test "decoded number schema validates both ints and floats (issue #65)" do
      {:ok, schema} = Peri.from_json_schema(%{"type" => "number"})
      assert {:ok, 5} = Peri.validate(schema, 5)
      assert {:ok, 5.5} = Peri.validate(schema, 5.5)
      assert {:error, _} = Peri.validate(schema, "x")
    end

    test "decoded integer schema also accepts zero-fractional floats per spec" do
      {:ok, schema} = Peri.from_json_schema(%{"type" => "integer"})
      assert {:ok, 5} = Peri.validate(schema, 5)
      assert {:ok, 5.0} = Peri.validate(schema, 5.0)
    end

    test "decoded constrained number applies bounds to both ints and floats" do
      {:ok, schema} = Peri.from_json_schema(%{"type" => "number", "minimum" => 0})
      assert {:ok, 0} = Peri.validate(schema, 0)
      assert {:ok, 0.5} = Peri.validate(schema, 0.5)
      assert {:error, _} = Peri.validate(schema, -1)
      assert {:error, _} = Peri.validate(schema, -0.5)
    end

    test "string pattern → regex" do
      json = %{"type" => "string", "pattern" => "^foo"}
      assert {:ok, {:string, {:regex, %Regex{}}}} = Peri.from_json_schema(json)
    end

    test "invalid regex pattern is dropped, not raised" do
      json = %{"type" => "string", "pattern" => "["}
      assert {:ok, :string} = Peri.from_json_schema(json)
    end

    test "default :keys opt yields string keys regardless of atom-table state" do
      missing = "missing_atom_#{System.unique_integer([:positive])}"

      json = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          missing => %{"type" => "integer"}
        }
      }

      assert {:ok, schema} = Peri.from_json_schema(json)
      assert schema["name"] == :string
      assert schema[missing] == {:either, {:integer, :float}}
      assert Enum.all?(Map.keys(schema), &is_binary/1)
    end
  end

  describe "from_json_schema/2 — :keys option" do
    test ":strings (explicit) keeps all keys as binaries" do
      json = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}, "age" => %{"type" => "integer"}},
        "required" => ["name"]
      }

      assert {:ok, schema} = Peri.from_json_schema(json, keys: :strings)
      assert schema["name"] == {:required, :string}
      assert schema["age"] == {:either, {:integer, :float}}
    end

    test ":atoms uses existing atoms" do
      json = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      assert {:ok, schema} = Peri.from_json_schema(json, keys: :atoms)
      assert schema[:name] == {:required, :string}
      assert schema[:age] == {:either, {:integer, :float}}
    end

    test ":atoms falls back to string when atom does not exist" do
      missing = "peri_test_missing_atom_#{System.unique_integer([:positive])}"

      json = %{
        "type" => "object",
        "properties" => %{missing => %{"type" => "string"}}
      }

      assert {:ok, schema} = Peri.from_json_schema(json, keys: :atoms)
      assert schema[missing] == :string
    end

    test ":atoms! force-creates atoms for every key" do
      missing_1 = "peri_test_atoms_bang_1_#{System.unique_integer([:positive])}"
      missing_2 = "peri_test_atoms_bang_2_#{System.unique_integer([:positive])}"

      json = %{
        "type" => "object",
        "properties" => %{
          missing_1 => %{"type" => "string"},
          missing_2 => %{"type" => "integer"}
        },
        "required" => [missing_1]
      }

      assert {:ok, schema} = Peri.from_json_schema(json, keys: :atoms!)
      assert schema[String.to_atom(missing_1)] == {:required, :string}
      assert schema[String.to_atom(missing_2)] == {:either, {:integer, :float}}
      assert Enum.all?(Map.keys(schema), &is_atom/1)
    end

    test "opt propagates into nested objects" do
      json = %{
        "type" => "object",
        "properties" => %{
          "outer" => %{
            "type" => "object",
            "properties" => %{"inner" => %{"type" => "string"}}
          }
        }
      }

      assert {:ok, %{outer: %{inner: :string}}} = Peri.from_json_schema(json, keys: :atoms)
    end

    test "opt propagates into oneOf branches that are objects" do
      json = %{
        "oneOf" => [
          %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}},
          %{"type" => "boolean"}
        ]
      }

      assert {:ok, {:either, {%{name: :string}, :boolean}}} =
               Peri.from_json_schema(json, keys: :atoms)
    end

    test "opt propagates into array items that are objects" do
      json = %{
        "type" => "array",
        "items" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
      }

      assert {:ok, {:list, %{name: :string}}} = Peri.from_json_schema(json, keys: :atoms)
    end

    test "opt propagates into $ref resolution" do
      json = %{
        "$defs" => %{
          "Item" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
        },
        "type" => "object",
        "properties" => %{"item" => %{"$ref" => "#/$defs/Item"}}
      }

      assert {:ok, %{item: %{name: :string}}} = Peri.from_json_schema(json, keys: :atoms)
    end

    test "opt propagates into allOf merged objects" do
      json = %{
        "allOf" => [
          %{"type" => "object", "properties" => %{"a" => %{"type" => "string"}}},
          %{"type" => "object", "properties" => %{"b" => %{"type" => "integer"}}}
        ]
      }

      assert {:ok, %{a: :string, b: {:either, {:integer, :float}}}} =
               Peri.from_json_schema(json, keys: :atoms)
    end

    test "unknown :keys value raises FunctionClauseError" do
      json = %{"type" => "object", "properties" => %{"x" => %{"type" => "string"}}}

      assert_raise FunctionClauseError, fn ->
        Peri.from_json_schema(json, keys: :bogus)
      end
    end
  end

  describe "round-trip" do
    test "primitives (string, boolean) round-trip exactly" do
      for type <- [:string, :boolean] do
        assert {:ok, ^type} = type |> Peri.to_json_schema() |> Peri.from_json_schema()
      end
    end

    test "numeric primitives widen to either int|float on decode (lossy by spec)" do
      for type <- [:integer, :float] do
        assert {:ok, {:either, {:integer, :float}}} =
                 type |> Peri.to_json_schema() |> Peri.from_json_schema()
      end
    end

    test "object with required" do
      schema = %{name: {:required, :string}, age: :integer}
      json = Peri.to_json_schema(schema)
      assert {:ok, decoded} = Peri.from_json_schema(json)
      assert decoded["name"] == {:required, :string}
      assert decoded["age"] == {:either, {:integer, :float}}
    end

    test "list of strings" do
      assert {:ok, {:list, :string}} =
               {:list, :string} |> Peri.to_json_schema() |> Peri.from_json_schema()
    end

    test "integer with gte widens to either with constraint on both branches" do
      assert {:ok, {:either, {{:integer, {:gte, 0}}, {:float, {:gte, 0}}}}} =
               {:integer, gte: 0} |> Peri.to_json_schema() |> Peri.from_json_schema()
    end

    test "object with atom keys recovered via keys: :atoms" do
      schema = %{name: {:required, :string}, age: :integer}
      json = Peri.to_json_schema(schema)

      assert {:ok, decoded} = Peri.from_json_schema(json, keys: :atoms)
      assert decoded[:name] == {:required, :string}
      assert decoded[:age] == {:either, {:integer, :float}}
    end

    test "object with unknown atom keys recovered via keys: :atoms!" do
      key = String.to_atom("peri_rt_atoms_bang_#{System.unique_integer([:positive])}")
      schema = %{key => {:required, :string}}
      json = Peri.to_json_schema(schema)

      assert {:ok, ^schema} = Peri.from_json_schema(json, keys: :atoms!)
    end
  end

  describe "to_json_schema/2 — typed enum" do
    test "without :type opt emits bare enum" do
      assert Peri.to_json_schema({:enum, [:a, :b], []}) == %{"enum" => [:a, :b]}
    end

    test "with :type opt emits type + enum" do
      assert Peri.to_json_schema({:enum, [1, 2, 3], type: :integer}) ==
               %{"type" => "integer", "enum" => [1, 2, 3]}

      assert Peri.to_json_schema({:enum, ["a", "b"], type: :string}) ==
               %{"type" => "string", "enum" => ["a", "b"]}
    end

    test ":type carries through nested constraint encoding" do
      assert Peri.to_json_schema({:enum, [1, 2], type: :integer}) ==
               %{"type" => "integer", "enum" => [1, 2]}
    end

    test ":error and :gen opts do not leak into JSON Schema" do
      schema = {:enum, [1, 2], type: :integer, error: "bad", gen: {Mod, :fun}}
      assert Peri.to_json_schema(schema) == %{"type" => "integer", "enum" => [1, 2]}
    end
  end

  describe "to_json_schema/2 — exclude_meta_keys" do
    test "drops :default from {type, {:default, _}}" do
      assert Peri.to_json_schema({:integer, {:default, 0}}, exclude_meta_keys: [:default]) ==
               %{"type" => "integer"}
    end

    test "drops :default from {:meta, type, default: _}" do
      schema = {:meta, :integer, default: 0, description: "count"}

      assert Peri.to_json_schema(schema, exclude_meta_keys: [:default]) ==
               %{"type" => "integer", "description" => "count"}
    end

    test "preserves other meta keys when only :default excluded" do
      schema = {:meta, {:integer, {:default, 0}}, description: "count", deprecated: true}

      assert Peri.to_json_schema(schema, exclude_meta_keys: [:default]) ==
               %{"type" => "integer", "description" => "count", "deprecated" => true}
    end

    test "drops multiple keys" do
      schema = {:meta, :string, description: "x", deprecated: true, default: "y"}

      assert Peri.to_json_schema(schema, exclude_meta_keys: [:default, :deprecated]) ==
               %{"type" => "string", "description" => "x"}
    end

    test "without opt, default is included as before" do
      assert Peri.to_json_schema({:integer, {:default, 0}}) ==
               %{"type" => "integer", "default" => 0}
    end
  end

  describe "from_json_schema/1 — typed enum" do
    test "type + enum → typed enum tuple" do
      assert {:ok, {:enum, [1, 2, 3], type: :integer}} =
               Peri.from_json_schema(%{"type" => "integer", "enum" => [1, 2, 3]})
    end

    test "string type + enum" do
      assert {:ok, {:enum, ["a", "b"], type: :string}} =
               Peri.from_json_schema(%{"type" => "string", "enum" => ["a", "b"]})
    end

    test "number type + enum decodes to :float" do
      assert {:ok, {:enum, [1.0, 2.5], type: :float}} =
               Peri.from_json_schema(%{"type" => "number", "enum" => [1.0, 2.5]})
    end

    test "unknown primitive type falls back to bare enum" do
      assert {:ok, {:enum, [1, 2]}} =
               Peri.from_json_schema(%{"type" => "object", "enum" => [1, 2]})
    end
  end

  describe "round-trip — typed enum" do
    test "preserves :type opt" do
      schema = {:enum, [1, 2, 3], type: :integer}
      assert {:ok, ^schema} = schema |> Peri.to_json_schema() |> Peri.from_json_schema()
    end
  end
end
