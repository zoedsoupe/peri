defmodule Peri.GenOverridesTest do
  use ExUnit.Case, async: true

  defmodule Gens do
    def adult_age, do: StreamData.integer(18..120)
    def email_with_prefix(prefix), do: StreamData.constant(prefix <> "@test.io")
    def fixed_login, do: StreamData.constant("system")
  end

  defp sample(stream, n \\ 20)
  defp sample({:ok, stream}, n), do: Enum.take(stream, n)
  defp sample(%StreamData{} = stream, n), do: Enum.take(stream, n)

  describe "validate_schema accepts :gen opt" do
    test "MFA in multi-options" do
      schema = %{age: {:integer, gte: 18, gen: {Gens, :adult_age, []}}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "MF (no args) in :required wrapper" do
      schema = %{login: {:required, :string, [gen: {Gens, :fixed_login}]}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "0-arity fun in :meta wrapper" do
      fun = fn -> StreamData.constant("x") end
      schema = %{name: {:meta, :string, [gen: fun]}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "rejects non-MFA / non-fun gen value" do
      schema = %{age: {:integer, gte: 18, gen: 123}}
      assert {:error, _} = Peri.validate_schema(schema)
    end

    test "rejects 1-arity fun" do
      schema = %{age: {:integer, gte: 18, gen: fn _ -> StreamData.integer() end}}
      assert {:error, _} = Peri.validate_schema(schema)
    end

    test "rejects bad gen in :required" do
      schema = %{x: {:required, :string, [gen: 42]}}
      assert {:error, _} = Peri.validate_schema(schema)
    end

    test "rejects bad gen in :meta" do
      schema = %{x: {:meta, :string, [gen: :nope]}}
      assert {:error, _} = Peri.validate_schema(schema)
    end
  end

  describe "Peri.Generatable consumes :gen override" do
    test "multi-options uses override, skipping rejection sampling" do
      schema = %{age: {:integer, gte: 18, gen: {Gens, :adult_age, []}}}

      values =
        schema
        |> Peri.generate()
        |> sample()

      assert Enum.all?(values, fn %{age: a} -> a >= 18 and a <= 120 end)
    end

    test ":required override fires" do
      schema = %{login: {:required, :string, [gen: {Gens, :fixed_login}]}}

      values =
        schema
        |> Peri.generate()
        |> sample(5)

      assert Enum.all?(values, fn %{login: v} -> v == "system" end)
    end

    test ":meta override fires" do
      fun = fn -> StreamData.constant("hello") end
      schema = %{name: {:meta, :string, [gen: fun]}}

      values =
        schema
        |> Peri.generate()
        |> sample(5)

      assert Enum.all?(values, fn %{name: v} -> v == "hello" end)
    end

    test "MFA with args is applied" do
      schema = %{email: {:meta, :string, [gen: {Gens, :email_with_prefix, ["zoey"]}]}}

      values =
        schema
        |> Peri.generate()
        |> sample(3)

      assert Enum.all?(values, fn %{email: v} -> v == "zoey@test.io" end)
    end

    test "without override, multi-options falls back to constraint chain" do
      schema = %{n: {:integer, gte: 0, lte: 10}}

      values =
        schema
        |> Peri.generate()
        |> sample(20)

      assert Enum.all?(values, fn %{n: v} -> v >= 0 and v <= 10 end)
    end

    test "without override, :required and :meta delegate to inner type generator" do
      schema = %{
        a: {:required, :integer, []},
        b: {:meta, :integer, doc: "x"}
      }

      values =
        schema
        |> Peri.generate()
        |> sample(5)

      assert Enum.all?(values, fn %{a: a, b: b} ->
               is_integer(a) and is_integer(b)
             end)
    end
  end

  describe "validates generated data" do
    test "override values pass schema validation" do
      schema = %{age: {:integer, gte: 18, gen: {Gens, :adult_age, []}}}

      values =
        schema
        |> Peri.generate()
        |> sample(10)

      Enum.each(values, fn data -> assert {:ok, ^data} = Peri.validate(schema, data) end)
    end
  end
end
