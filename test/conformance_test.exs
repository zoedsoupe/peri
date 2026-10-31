defmodule Peri.ConformanceTest do
  use ExUnit.Case, async: true

  @schema %{
    name: {:required, {:string, [min: 2, max: 12]}},
    age: {:required, {:integer, [gte: 18, lte: 120]}},
    status: {:enum, ["ready", "paused"]},
    scores: {:list, :integer, [min: 1, max: 4]},
    profile: %{
      nickname: {:required, :string},
      active: {:required, :boolean}
    }
  }

  @valid_data %{
    name: "Ada",
    age: 37,
    status: "ready",
    scores: [3, 5],
    profile: %{nickname: "ada", active: true}
  }

  @acceptance_corpus [
    {@valid_data, true},
    {Map.delete(@valid_data, :name), false},
    {Map.put(@valid_data, :age, 17), false},
    {Map.put(@valid_data, :status, "unknown"), false},
    {Map.put(@valid_data, :scores, [3, "five"]), false},
    {put_in(@valid_data, [:profile, :nickname], nil), false}
  ]

  test "core, generated data, JSON Schema, and Ecto agree on the shared corpus" do
    assert {:ok, generator} = Peri.generate(@schema)

    for sample <- Enum.take(generator, 25) do
      assert {:ok, _validated} = Peri.validate(@schema, sample)
    end

    assert {:ok, json_schema} =
             @schema |> Peri.to_json_schema() |> Peri.from_json_schema(keys: :atoms)

    for {data, expected?} <- @acceptance_corpus do
      assert accepted?(Peri.validate(@schema, data)) == expected?
      assert accepted?(Peri.validate(json_schema, data)) == expected?

      changeset = Peri.to_changeset!(@schema, data)
      assert changeset.valid? == expected?
    end
  end

  test "Phoenix forms expose errors from the shared schema" do
    params = %{
      "name" => "Ada",
      "age" => "17",
      "status" => "ready",
      "scores" => ["3"],
      "profile" => %{"nickname" => "ada", "active" => "true"}
    }

    form = Peri.Phoenix.to_form(@schema, params)

    assert form.action == :validate
    assert form[:age].errors != []
    assert Enum.all?(form[:age].errors, fn {message, _opts} -> is_binary(message) end)
  end

  test "additional object keys retain their schema-valued validation" do
    schema = %{
      metadata: {:schema, %{label: {:required, :string}}, {:additional_keys, :integer}}
    }

    valid = %{metadata: %{label: "release", revision: 3}}
    invalid = %{metadata: %{label: "release", revision: "three"}}

    assert {:ok, json_schema} =
             schema |> Peri.to_json_schema() |> Peri.from_json_schema(keys: :atoms)

    for candidate <- [schema, json_schema] do
      assert {:ok, _} = Peri.validate(candidate, valid)
      assert {:error, _} = Peri.validate(candidate, invalid)
    end
  end

  test "coerced list elements preserve unchanged values beside converted values" do
    schema = %{values: {:list, {:coerce, :string, :integer}}}

    assert {:ok, %{values: [1, 2, 3, 4]}} =
             Peri.validate(schema, %{values: [1, "2", 3, "4"]})
  end

  test "transformed list elements preserve values unchanged by the transform" do
    schema = %{values: {:list, {:string, {:transform, &String.trim/1}}}}

    assert {:ok, %{values: ["first", "middle", "last"]}} =
             Peri.validate(schema, %{values: [" first", "middle", "last "]})
  end

  test "coercion has equivalent core, Ecto, and Phoenix boundary behavior" do
    schema = %{age: {:coerce, :string, {:integer, {:gte, 18}}}}
    valid = %{"age" => "21"}
    invalid = %{"age" => "17"}

    assert {:ok, %{age: 21}} = Peri.decode(schema, valid)
    assert {:error, _} = Peri.decode(schema, invalid)

    valid_changeset = Peri.to_changeset!(schema, valid)
    invalid_changeset = Peri.to_changeset!(schema, invalid)
    assert valid_changeset.valid?
    assert Ecto.Changeset.get_change(valid_changeset, :age) == 21
    refute invalid_changeset.valid?

    valid_form = Peri.Phoenix.to_form(schema, valid)
    invalid_form = Peri.Phoenix.to_form(schema, invalid)
    assert valid_form.source.data.age == 21
    assert [{message, _opts}] = invalid_form[:age].errors
    assert is_binary(message)
  end

  defp accepted?({:ok, _}), do: true
  defp accepted?({:error, _}), do: false
end
