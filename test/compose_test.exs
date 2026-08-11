defmodule Peri.ComposeTest do
  use ExUnit.Case, async: true

  import Peri

  doctest Peri, only: [merge: 2, select: 2, except: 2]

  defschema(:user, %{
    name: {:required, :string},
    age: :integer
  })

  describe "merge/2" do
    test "combines disjoint fields" do
      assert {:ok, %{name: :string, age: :integer}} =
               Peri.merge(%{name: :string}, %{age: :integer})
    end

    test "right side wins on overlapping field" do
      assert {:ok, %{name: :atom}} = Peri.merge(%{name: :string}, %{name: :atom})
    end

    test "deep merges nested maps preserving fields from both sides" do
      left = %{user: %{name: :string, profile: %{bio: :string}}}
      right = %{user: %{age: :integer, profile: %{avatar: :string}}}

      assert {:ok,
              %{
                user: %{
                  name: :string,
                  age: :integer,
                  profile: %{bio: :string, avatar: :string}
                }
              }} = Peri.merge(left, right)
    end

    test "right side wins on conflicting nested leaf" do
      left = %{user: %{name: :string}}
      right = %{user: %{name: {:required, :string}}}

      assert {:ok, %{user: %{name: {:required, :string}}}} = Peri.merge(left, right)
    end

    test "type tuples are never merged structurally" do
      left = %{tags: {:list, :string}}
      right = %{tags: {:list, :integer}}

      assert {:ok, %{tags: {:list, :integer}}} = Peri.merge(left, right)
    end

    test "merged schema validates data correctly" do
      {:ok, base} = Peri.merge(%{name: {:required, :string}}, %{age: :integer})
      {:ok, schema} = Peri.merge(base, %{admin: :boolean})

      assert {:ok, %{name: "Zoey", age: 30, admin: true}} =
               Peri.validate(schema, %{name: "Zoey", age: 30, admin: true})

      assert {:error, _} = Peri.validate(schema, %{age: 30})
    end

    test "round-trips a defschema through merge" do
      {:ok, extended} = Peri.merge(get_schema(:user), %{role: {:enum, [:admin, :member]}})

      data = %{name: "Zoey", age: 30, role: :admin}
      assert {:ok, ^data} = Peri.validate(extended, data)
      assert {:error, _} = Peri.validate(extended, %{name: "Zoey", role: :root})
    end

    test "returns error when the merged result is invalid" do
      assert {:error, _} = Peri.merge(%{name: :string}, %{age: :str})
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Peri.merge(:string, %{}) end
      assert_raise ArgumentError, fn -> Peri.merge(%{}, :string) end
    end
  end

  describe "select/2" do
    test "keeps only the given keys" do
      schema = %{name: :string, age: :integer, email: :string}

      assert {:ok, %{name: :string, email: :string}} = Peri.select(schema, [:name, :email])
    end

    test "ignores keys not present in the schema" do
      assert {:ok, %{name: :string}} = Peri.select(%{name: :string}, [:name, :missing])
    end

    test "empty selection returns an empty schema" do
      assert {:ok, schema} = Peri.select(%{name: :string}, [])
      assert map_size(schema) == 0
    end

    test "selected schema validates data correctly" do
      {:ok, public} = Peri.select(%{name: :string, password: :string}, [:name])

      assert {:ok, %{name: "Zoey"}} = Peri.validate(public, %{name: "Zoey", password: "secret"})
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Peri.select(:string, [:name]) end
    end
  end

  describe "except/2" do
    test "drops the given keys" do
      schema = %{name: :string, age: :integer, email: :string}

      assert {:ok, %{name: :string, age: :integer}} = Peri.except(schema, [:email])
    end

    test "ignores keys not present in the schema" do
      assert {:ok, %{name: :string}} = Peri.except(%{name: :string}, [:missing])
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Peri.except(:string, [:name]) end
    end
  end
end
