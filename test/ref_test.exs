defmodule Peri.RefTest do
  use ExUnit.Case, async: true

  import Peri

  defmodule Trees do
    import Peri

    defschema(:tree, %{
      value: {:required, :integer},
      children: {:list, {:ref, :tree}}
    })

    defschema(:branch, %{
      label: {:required, :string},
      sub: {:ref, :tree}
    })
  end

  defmodule Other do
    import Peri

    defschema(:node, %{
      id: {:required, :integer},
      name: :string
    })
  end

  defmodule Cross do
    import Peri

    defschema(:graph, %{
      root: {:ref, {Trees, :tree}},
      related: {:list, {:ref, {Other, :node}}}
    })
  end

  describe "local refs" do
    test "validates a leaf tree" do
      assert {:ok, %{value: 1, children: []}} =
               Trees.tree(%{value: 1, children: []})
    end

    test "validates a recursive tree" do
      data = %{
        value: 1,
        children: [
          %{value: 2, children: []},
          %{value: 3, children: [%{value: 4, children: []}]}
        ]
      }

      assert {:ok, ^data} = Trees.tree(data)
    end

    test "rejects bad nested data" do
      data = %{value: 1, children: [%{value: "bad", children: []}]}
      assert {:error, _} = Trees.tree(data)
    end

    test "ref inside another schema" do
      data = %{label: "x", sub: %{value: 1, children: []}}
      assert {:ok, ^data} = Trees.branch(data)
    end
  end

  describe "cross-module refs" do
    test "validates with explicit module" do
      data = %{
        root: %{value: 1, children: []},
        related: [%{id: 1, name: "a"}]
      }

      assert {:ok, ^data} = Cross.graph(data)
    end
  end

  describe "ref errors" do
    defmodule Broken do
      import Peri
      defschema(:thing, %{x: {:ref, :missing}})
    end

    test "missing ref name surfaces a clear error" do
      assert {:error, [%Peri.Error{message: msg}]} = Broken.thing(%{x: %{}})
      assert msg =~ "ref" and msg =~ "not defined"
    end

    test "non-existent module surfaces a clear error" do
      schema = %{x: {:ref, {NotARealModule, :foo}}}
      assert {:error, [%Peri.Error{message: msg}]} = Peri.validate(schema, %{x: %{}})
      assert msg =~ "not loaded"
    end
  end

  describe "JSON Schema export" do
    test "ref emits $ref and $defs" do
      schema = %{root: {:ref, {Other, :node}}}
      json = Peri.to_json_schema(schema)

      assert json["properties"]["root"] == %{"$ref" => "#/$defs/Peri_RefTest_Other_node"}
      assert is_map(json["$defs"])
      def_body = json["$defs"]["Peri_RefTest_Other_node"]
      assert def_body["type"] == "object"
      assert def_body["required"] == ["id"]
    end
  end

  if Code.ensure_loaded?(Ecto) do
    describe "Ecto integration" do
      test "ref degrades to :map on changeset side" do
        schema = %{node: {:ref, {Other, :node}}}
        cs = Peri.to_changeset!(schema, %{node: %{id: 1, name: "a"}})
        assert cs.valid?
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    describe "data generation" do
      test "produces values bounded by depth limit" do
        {:ok, stream} = Peri.generate(%{root: {:ref, {Other, :node}}})
        [data] = Enum.take(stream, 1)
        assert is_map(data)
      end
    end
  end
end
