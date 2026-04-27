defmodule Peri.MultiTest do
  use ExUnit.Case, async: true

  import Peri

  defschema(:shape, %{
    shape:
      {:multi, :type,
       %{
         "circle" => %{type: {:required, :string}, radius: {:required, :float}},
         "rect" => %{type: {:required, :string}, w: {:required, :float}, h: {:required, :float}}
       }}
  })

  describe ":multi dispatch" do
    test "validates the matching branch" do
      data = %{shape: %{type: "circle", radius: 1.5}}
      assert {:ok, ^data} = shape(data)

      data = %{shape: %{type: "rect", w: 2.0, h: 3.0}}
      assert {:ok, ^data} = shape(data)
    end

    test "branch validation errors propagate with branch path" do
      data = %{shape: %{type: "circle", radius: "not-a-float"}}

      assert {:error,
              [
                %Peri.Error{
                  path: [:shape],
                  errors: [%Peri.Error{path: [:shape, :radius]}]
                }
              ]} = shape(data)
    end

    test "missing dispatch field surfaces clear error" do
      data = %{shape: %{radius: 1.0}}
      assert {:error, [%Peri.Error{message: msg}]} = shape(data)
      assert msg =~ "missing :multi dispatch field"
    end

    test "unknown dispatch tag surfaces clear error including known tags" do
      data = %{shape: %{type: "triangle", side: 2.0}}
      assert {:error, [%Peri.Error{message: msg}]} = shape(data)
      assert msg =~ "no :multi branch matches"
      assert msg =~ "circle"
      assert msg =~ "rect"
    end
  end

  describe "validate_schema" do
    test "rejects non-atom dispatch field" do
      schema = %{x: {:multi, "type", %{"a" => %{}}}}
      assert {:error, _} = Peri.validate_schema(schema)
    end

    test "rejects non-map branches" do
      schema = %{x: {:multi, :type, [{"a", %{}}]}}
      assert {:error, _} = Peri.validate_schema(schema)
    end

    test "accepts well-formed multi" do
      schema = %{x: {:multi, :type, %{"a" => %{n: :integer}, "b" => %{s: :string}}}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end
  end

  describe "JSON Schema export" do
    test "emits oneOf with discriminator" do
      schema = %{
        shape:
          {:multi, :type,
           %{
             "circle" => %{r: {:required, :float}},
             "rect" => %{w: {:required, :float}}
           }}
      }

      json = Peri.to_json_schema(schema)
      multi = json["properties"]["shape"]

      assert is_list(multi["oneOf"])
      assert length(multi["oneOf"]) == 2
      assert multi["discriminator"] == %{"propertyName" => "type"}

      const_tags =
        multi["oneOf"]
        |> Enum.map(& &1["properties"]["type"]["const"])
        |> Enum.sort()

      assert const_tags == ["circle", "rect"]
    end
  end

  if Code.ensure_loaded?(StreamData) do
    describe "data generation" do
      test "samples a branch and merges dispatch tag" do
        schema =
          {:multi, :type,
           %{
             "circle" => %{r: :float},
             "rect" => %{w: :float}
           }}

        {:ok, stream} = Peri.generate(schema)

        Enum.take(stream, 20)
        |> Enum.each(fn val ->
          assert is_map(val)
          assert val[:type] in ["circle", "rect"]
        end)
      end
    end
  end
end
