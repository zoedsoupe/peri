defmodule Peri.JSONSchemaTest do
  use ExUnit.Case, async: true

  alias Peri.JSONSchema.Encoder.UnsupportedTypeError

  defmodule ReferenceSchemas do
    import Peri

    defschema(:node, %{id: {:required, :integer}})
  end

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

    test "required options are omitted from validation but retain requiredness" do
      schema = [name: {:required, :string, error: "missing name"}]

      assert Peri.to_json_schema(schema) == %{
               "type" => "object",
               "properties" => %{"name" => %{"type" => "string"}},
               "required" => ["name"]
             }

      assert {:ok, decoded} = schema |> Peri.to_json_schema() |> Peri.from_json_schema()
      assert decoded["name"] == {:required, :string}
    end

    test "keyword schemas and named schema wrappers encode as objects" do
      keyword_schema = [name: :string]
      named_schema = {:schema, keyword_schema, name: "Person", description: "A person"}

      json = Peri.to_json_schema(keyword_schema)

      assert json["type"] == "object"
      assert json["properties"]["name"] == %{"type" => "string"}
      assert Peri.to_json_schema(named_schema) == json
      assert {:ok, %{name: :string}} = json |> Peri.from_json_schema(keys: :atoms)
    end

    test "refs use Draft 7 definitions and keep a $defs alias" do
      json = Peri.to_json_schema(%{node: {:ref, {ReferenceSchemas, :node}}})
      ref = json["properties"]["node"]["$ref"]

      assert ref == "#/definitions/Peri_JSONSchemaTest_ReferenceSchemas_node"
      assert json["definitions"] == json["$defs"]

      assert json["definitions"]["Peri_JSONSchemaTest_ReferenceSchemas_node"]["required"] == [
               "id"
             ]
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

  describe "to_json_schema/2 — supported wrappers" do
    test "coercion target forms encode their target schema" do
      for schema <- [
            {:coerce, :integer},
            {:coerce, :integer, error: "invalid"},
            {:coerce, :string, :integer},
            {:coerce, :string, :integer, error: "invalid"}
          ] do
        assert Peri.to_json_schema(schema) == %{"type" => "integer"}
        assert {:ok, expected} = schema |> Peri.to_json_schema() |> Peri.from_json_schema()
        assert expected == integer_schema()
      end
    end

    test ":atom! encodes as a string schema" do
      assert Peri.to_json_schema(:atom!) == %{"type" => "string"}
      assert {:ok, :string} = :atom! |> Peri.to_json_schema() |> Peri.from_json_schema()
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
      assert schema["age"] == integer_schema()
    end

    test "primitives" do
      assert {:ok, :string} = Peri.from_json_schema(%{"type" => "string"})
      assert {:ok, :boolean} = Peri.from_json_schema(%{"type" => "boolean"})
      assert {:ok, {:literal, nil}} = Peri.from_json_schema(%{"type" => "null"})
    end

    test "integer and number use their JSON Schema numeric semantics" do
      assert {:ok, {:either, {:integer, :float}}} =
               Peri.from_json_schema(%{"type" => "number"})

      expected_integer = integer_schema()
      assert {:ok, ^expected_integer} = Peri.from_json_schema(%{"type" => "integer"})
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

    test "integer minimum applies to integers and integral floats" do
      json = %{"type" => "integer", "minimum" => 0}

      assert {:ok, schema} = Peri.from_json_schema(json)
      assert schema == integer_schema(json)
      assert {:ok, 0} = Peri.validate(schema, 0)
      assert {:ok, zero_float} = Peri.validate(schema, 0.0)
      assert zero_float == 0.0
      assert {:ok, 1.0} = Peri.validate(schema, 1.0)
      assert {:error, _} = Peri.validate(schema, -1)
      assert {:error, _} = Peri.validate(schema, -0.5)
      assert {:error, _} = Peri.validate(schema, 0.5)
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
      assert {:error, _} = Peri.validate(schema, 5.5)
    end

    test "integer enum enforces membership and integer semantics" do
      {:ok, schema} = Peri.from_json_schema(%{"type" => "integer", "enum" => [5, 6]})
      assert {:ok, 5} = Peri.validate(schema, 5)
      assert {:ok, 5.0} = Peri.validate(schema, 5.0)
      assert {:error, _} = Peri.validate(schema, 5.5)
      assert {:error, _} = Peri.validate(schema, 7)
    end

    test "number enum accepts integer and floating enum members" do
      {:ok, schema} = Peri.from_json_schema(%{"type" => "number", "enum" => [5, 5.5]})
      assert {:ok, 5} = Peri.validate(schema, 5)
      assert {:ok, 5.0} = Peri.validate(schema, 5.0)
      assert {:ok, 5.5} = Peri.validate(schema, 5.5)
      assert {:error, _} = Peri.validate(schema, 6)
    end

    test "objects retain and validate additional properties alongside declared properties" do
      json = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}},
        "required" => ["name"],
        "additionalProperties" => %{"type" => "integer"}
      }

      assert {:ok, schema} = Peri.from_json_schema(json)

      assert {:ok, %{"name" => "Ada", "age" => 37}} =
               Peri.validate(schema, %{"name" => "Ada", "age" => 37})

      assert {:error, _} = Peri.validate(schema, %{"name" => "Ada", "age" => "old"})
      assert {:error, _} = Peri.validate(schema, %{"age" => 37})
    end

    test "schema-valued additional properties survive an encode/decode round-trip" do
      schema = {:schema, %{"name" => {:required, :string}}, {:additional_keys, :integer}}

      assert {:ok, decoded} = schema |> Peri.to_json_schema() |> Peri.from_json_schema()

      assert {:ok, %{"name" => "Ada", "age" => 37}} =
               Peri.validate(decoded, %{"name" => "Ada", "age" => 37})

      assert {:error, _} = Peri.validate(decoded, %{"name" => "Ada", "age" => "old"})
    end

    test "Draft 7 definitions and legacy $defs refs both decode" do
      definition = %{"type" => "object", "properties" => %{"id" => %{"type" => "integer"}}}

      for ref_key <- ["definitions", "$defs"] do
        json = %{
          ref_key => %{"Node" => definition},
          "type" => "object",
          "properties" => %{"node" => %{"$ref" => "#/" <> ref_key <> "/Node"}}
        }

        assert {:ok, %{"node" => schema}} = Peri.from_json_schema(json)
        assert schema["id"] == integer_schema()
      end
    end

    test "recursive local refs return a controlled error" do
      json = %{
        "definitions" => %{
          "Node" => %{
            "type" => "object",
            "properties" => %{"child" => %{"$ref" => "#/definitions/Node"}}
          }
        },
        "type" => "object",
        "properties" => %{"root" => %{"$ref" => "#/definitions/Node"}}
      }

      assert {:error, {:recursive_ref, "Node"}} = Peri.from_json_schema(json)
    end

    test "allOf rejects conflicting property schemas instead of merging them silently" do
      json = %{
        "allOf" => [
          %{"type" => "object", "properties" => %{"value" => %{"type" => "string"}}},
          %{"type" => "object", "properties" => %{"value" => %{"type" => "integer"}}}
        ]
      }

      assert {:error, {:all_of_conflict, "value", :string, integer}} =
               Peri.from_json_schema(json)

      assert integer == integer_schema()
    end

    test "additionalProperties false cannot be represented as rejection" do
      json = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}},
        "additionalProperties" => false
      }

      assert {:ok, schema} = Peri.from_json_schema(json)
      assert {:ok, _} = Peri.validate(schema, %{"name" => "Ada", "extra" => true})
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
      assert schema[missing] == integer_schema()
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
      assert schema["age"] == integer_schema()
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
      assert schema[:age] == integer_schema()
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
      assert schema[String.to_atom(missing_2)] == integer_schema()
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

      assert {:ok, %{a: :string, b: integer_type}} =
               Peri.from_json_schema(json, keys: :atoms)

      assert integer_type == integer_schema()
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

    test "integer round-trip keeps integral-float semantics and float widens to number" do
      assert {:ok, expected_integer} =
               :integer |> Peri.to_json_schema() |> Peri.from_json_schema()

      assert expected_integer == integer_schema()

      assert {:ok, {:either, {:integer, :float}}} =
               :float |> Peri.to_json_schema() |> Peri.from_json_schema()
    end

    test "object with required" do
      schema = %{name: {:required, :string}, age: :integer}
      json = Peri.to_json_schema(schema)
      assert {:ok, decoded} = Peri.from_json_schema(json)
      assert decoded["name"] == {:required, :string}
      assert decoded["age"] == integer_schema()
    end

    test "list of strings" do
      assert {:ok, {:list, :string}} =
               {:list, :string} |> Peri.to_json_schema() |> Peri.from_json_schema()
    end

    test "integer with gte round-trips integral-float constraints" do
      assert {:ok, decoded} =
               {:integer, gte: 0} |> Peri.to_json_schema() |> Peri.from_json_schema()

      assert decoded == integer_schema(%{"type" => "integer", "minimum" => 0})
    end

    test "object with atom keys recovered via keys: :atoms" do
      schema = %{name: {:required, :string}, age: :integer}
      json = Peri.to_json_schema(schema)

      assert {:ok, decoded} = Peri.from_json_schema(json, keys: :atoms)
      assert decoded[:name] == {:required, :string}
      assert decoded[:age] == integer_schema()
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
      assert {:ok, {:enum, [1, 1.0, 2, 2.0, 3, 3.0], type: type}} =
               Peri.from_json_schema(%{"type" => "integer", "enum" => [1, 2, 3]})

      assert type == integer_schema(%{"type" => "integer", "enum" => [1, 2, 3]})
    end

    test "string type + enum" do
      assert {:ok, {:enum, ["a", "b"], type: :string}} =
               Peri.from_json_schema(%{"type" => "string", "enum" => ["a", "b"]})
    end

    test "number type + enum decodes to a number union" do
      assert {:ok, {:enum, [1.0, 1, 2.5], type: {:either, {:integer, :float}}}} =
               Peri.from_json_schema(%{"type" => "number", "enum" => [1.0, 2.5]})
    end

    test "unknown primitive type falls back to bare enum" do
      assert {:ok, {:enum, [1, 2]}} =
               Peri.from_json_schema(%{"type" => "object", "enum" => [1, 2]})
    end
  end

  describe "round-trip — typed enum" do
    test "preserves typed integer enum semantics" do
      schema = {:enum, [1, 2, 3], type: :integer}

      assert {:ok, {:enum, [1, 1.0, 2, 2.0, 3, 3.0], type: type}} =
               schema |> Peri.to_json_schema() |> Peri.from_json_schema()

      assert type == integer_schema(%{"type" => "integer", "enum" => [1, 2, 3]})
    end
  end

  defp integer_schema(json_schema \\ %{"type" => "integer"}) do
    integer = numeric_branch(:integer, json_schema)

    {:either,
     {integer, {:custom, {Peri.JSONSchema.Decoder, :validate_integral_float, [json_schema]}}}}
  end

  defp numeric_branch(type, schema) do
    options =
      [
        {"minimum", :gte},
        {"maximum", :lte},
        {"exclusiveMinimum", :gt},
        {"exclusiveMaximum", :lt},
        {"multipleOf", :multiple_of}
      ]
      |> Enum.flat_map(fn {key, option} ->
        case Map.fetch(schema, key) do
          {:ok, value} -> [{option, value}]
          :error -> []
        end
      end)

    case options do
      [] -> type
      [single] -> {type, single}
      multiple -> {type, multiple}
    end
  end
end
