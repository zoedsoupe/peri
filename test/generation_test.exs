defmodule Peri.GenerationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  defmodule TransformHelpers do
    def with_root(value, %{prefix: prefix}), do: prefix <> value
    def integer_string, do: StreamData.string(?0..?9, min_length: 1, max_length: 4)
  end

  defmodule RecursiveSchemas do
    import Peri

    defschema(:node, %{
      id: {:required, :integer},
      child: {:ref, :node}
    })

    defschema(:required_node, %{
      id: {:required, :integer},
      child: {:required, {:ref, :required_node}}
    })
  end

  @supported_types [
    :any,
    :atom,
    :atom!,
    :boolean,
    :date,
    :datetime,
    :duration,
    :float,
    :integer,
    :list,
    :map,
    :naive_datetime,
    :pid,
    :string,
    :time
  ]

  @all_required_types Map.new(@supported_types, fn type -> {type, {:required, type}} end)

  property "generated samples for every supported built-in type validate" do
    generators =
      Enum.map(@supported_types, fn type ->
        {:ok, generator} = Peri.generate(type)
        StreamData.map(generator, &{type, &1})
      end)

    check all({type, sample} <- StreamData.one_of(generators), max_runs: 100) do
      assert {:ok, _validated} = Peri.validate(type, sample)
    end

    Enum.each(@supported_types, fn type ->
      assert {:ok, generator} = Peri.generate(type)

      Enum.each(Enum.take(generator, 20), fn sample ->
        assert {:ok, _validated} = Peri.validate(type, sample)
      end)
    end)

    assert {:ok, generator} = Peri.generate(@all_required_types)

    check all(sample <- generator, max_runs: 50) do
      assert {:ok, _validated} = Peri.validate(@all_required_types, sample)
    end

    Enum.each(Enum.take(generator, 20), fn sample ->
      assert {:ok, _validated} = Peri.validate(@all_required_types, sample)
    end)
  end

  property "combined integer and string constraints generate validating samples" do
    schema = %{
      greater_than: {:required, {:integer, [gt: 3.5, lt: 9]}},
      less_than: {:required, {:integer, [gte: -4, lt: 2.5]}},
      range: {:required, {:integer, [range: {2.5, 6.5}, gte: 3]}},
      multiple: {:required, {:integer, [gt: 0, lte: 21, multiple_of: 5]}},
      string_bounds: {:required, {:string, [min: 3, max: 7]}},
      exact_string: {:required, {:string, [eq: "peri", min: 2, max: 8]}}
    }

    assert {:ok, generator} = Peri.generate(schema)

    check all(sample <- generator, max_runs: 50) do
      assert {:ok, _validated} = Peri.validate(schema, sample)
      assert sample.greater_than >= 4 and sample.greater_than < 9
      assert sample.less_than >= -4 and sample.less_than <= 2
      assert sample.range in 3..6
      assert sample.multiple in [5, 10, 15, 20]
      assert String.length(sample.string_bounds) in 3..7
      assert sample.exact_string == "peri"
    end
  end

  describe "transforms" do
    test "one-arity functions preserve valid transformed samples" do
      schema = {:string, {:transform, &String.upcase/1}}
      assert {:ok, generator} = Peri.generate(schema)

      for sample <- Enum.take(generator, 20) do
        assert sample == String.upcase(sample)
        assert {:ok, _validated} = Peri.validate(schema, sample)
      end
    end

    test "MFA transforms use the value-and-arguments arity" do
      schema = {:string, {:transform, {String, :pad_leading, [5, "0"]}}}
      assert {:ok, generator} = Peri.generate(schema)

      for sample <- Enum.take(generator, 20) do
        assert String.length(sample) >= 5
        assert {:ok, _validated} = Peri.validate(schema, sample)
      end
    end

    test "type-changing callbacks retain valid underlying inputs" do
      input =
        {:string, [regex: ~r/^\d+$/, gen: {TransformHelpers, :integer_string}]}

      schema = {input, {:transform, &String.to_integer/1}}
      assert {:ok, generator} = Peri.generate(schema)

      for sample <- Enum.take(generator, 20) do
        assert is_binary(sample)
        assert {:ok, _validated} = Peri.validate(schema, sample)
      end
    end

    test "root-aware transforms generate underlying values without fake root data" do
      schema = %{
        prefix: {:required, :string},
        value: {:required, {:string, {:transform, fn value, root -> root.prefix <> value end}}},
        from_mfa: {:required, {:string, {:transform, {TransformHelpers, :with_root}}}}
      }

      assert {:ok, generator} = Peri.generate(schema)

      for sample <- Enum.take(generator, 20) do
        assert {:ok, _validated} = Peri.validate(schema, sample)
      end
    end
  end

  describe "optional and recursive fields" do
    test "optional map fields are generated while required fields remain valid" do
      schema = %{id: {:required, :integer}, name: :string}
      assert {:ok, generator} = Peri.generate(schema)
      samples = Enum.take(generator, 50)

      assert Enum.all?(samples, &Map.has_key?(&1, :id))
      assert Enum.all?(samples, &Map.has_key?(&1, :name))
      assert Enum.all?(samples, fn sample -> match?({:ok, _}, Peri.validate(schema, sample)) end)
    end

    test "optional recursive refs produce finite valid samples" do
      schema = RecursiveSchemas.get_schema(:node)
      assert {:ok, generator} = Peri.generate(schema)

      for sample <- Enum.take(generator, 20) do
        assert {:ok, _validated} = Peri.validate(schema, sample)
      end
    end

    test "required-only recursion is rejected instead of yielding invalid values" do
      assert_raise ArgumentError, ~r/no finite required base case/, fn ->
        Peri.generate(RecursiveSchemas.get_schema(:required_node))
      end
    end
  end
end
