defmodule Peri.WalkerTest do
  use ExUnit.Case, async: true

  doctest Peri, only: [walk: 2]

  describe "walk/2 — identity" do
    test "no-op callback preserves the schema" do
      schema = %{
        name: {:required, :string},
        age: {:integer, gte: 0, lte: 120},
        tags: {:list, :string},
        addr: %{street: :string, city: {:required, :string}}
      }

      assert Peri.walk(schema, &{:cont, &1}) == schema
    end

    test "preserves all directive shapes" do
      schema = %{
        a: {:enum, [:x, :y]},
        b: {:literal, :ok},
        c: {:either, {:string, :integer}},
        d: {:oneof, [:string, :integer, :atom]},
        e: {:tuple, [:float, :float]},
        f: {:map, :atom, :string},
        g: {:meta, {:required, :string}, doc: "x"},
        h: {:multi, :type, %{"a" => %{x: :string}, "b" => %{y: :integer}}},
        i: {:schema, %{k: :string}, {:additional_keys, :integer}},
        j: {:string, {:default, "x"}},
        k: {:integer, {:transform, &(&1 + 1)}},
        l: {:cond, fn _ -> true end, :string, :integer},
        m: {:custom, fn _ -> :ok end}
      }

      assert Peri.walk(schema, &{:cont, &1}) == schema
    end
  end

  describe "walk/2 — make-all-optional" do
    test "strips :required wrappers" do
      schema = %{
        name: {:required, :string},
        age: {:required, :integer},
        nested: %{x: {:required, :string}, y: :integer}
      }

      result =
        Peri.walk(schema, fn
          {:required, t} -> {:cont, t}
          other -> {:cont, other}
        end)

      assert result == %{
               name: :string,
               age: :integer,
               nested: %{x: :string, y: :integer}
             }
    end

    test "strips :required inside :list / :map / :either / :oneof / :tuple" do
      schema = %{
        items: {:list, {:required, :string}},
        m: {:map, {:required, :string}},
        e: {:either, {{:required, :string}, :integer}},
        o: {:oneof, [{:required, :string}, :integer]},
        t: {:tuple, [{:required, :float}, :float]}
      }

      result =
        Peri.walk(schema, fn
          {:required, t} -> {:cont, t}
          other -> {:cont, other}
        end)

      assert result == %{
               items: {:list, :string},
               m: {:map, :string},
               e: {:either, {:string, :integer}},
               o: {:oneof, [:string, :integer]},
               t: {:tuple, [:float, :float]}
             }
    end
  end

  describe "walk/2 — :drop on fields" do
    test "drops a top-level map field by key" do
      schema = %{name: :string, secret: :string, age: :integer}

      result =
        Peri.walk(schema, fn
          {:field, :secret, _} -> :drop
          other -> {:cont, other}
        end)

      assert result == %{name: :string, age: :integer}
    end

    test "drops a nested map field" do
      schema = %{outer: %{keep: :integer, drop_me: :string}}

      result =
        Peri.walk(schema, fn
          {:field, :drop_me, _} -> :drop
          other -> {:cont, other}
        end)

      assert result == %{outer: %{keep: :integer}}
    end

    test "drops based on field value" do
      schema = %{name: :string, secret: :string, age: :integer}

      result =
        Peri.walk(schema, fn
          {:field, _, :string} -> :drop
          other -> {:cont, other}
        end)

      assert result == %{age: :integer}
    end

    test "raises when :drop returned at root (type-expr position)" do
      assert_raise ArgumentError, ~r/:drop is only valid/, fn ->
        Peri.walk(%{a: :string}, fn _ -> :drop end)
      end
    end

    test "raises when :drop returned inside a tuple directive" do
      schema = %{x: {:list, :string}}

      assert_raise ArgumentError, ~r/:drop is only valid/, fn ->
        Peri.walk(schema, fn
          :string -> :drop
          other -> {:cont, other}
        end)
      end
    end
  end

  describe "walk/2 — rename fields" do
    test "renames a key via {:cont, {:field, new_k, v}}" do
      schema = %{email: {:required, :string}, age: :integer}

      result =
        Peri.walk(schema, fn
          {:field, :email, v} -> {:cont, {:field, :login, v}}
          other -> {:cont, other}
        end)

      assert result == %{login: {:required, :string}, age: :integer}
    end

    test "rename + recurse: child of new value still walked" do
      schema = %{outer: {:required, %{inner: {:required, :string}}}}

      result =
        Peri.walk(schema, fn
          {:field, :outer, v} -> {:cont, {:field, :renamed, v}}
          {:required, t} -> {:cont, t}
          other -> {:cont, other}
        end)

      assert result == %{renamed: %{inner: :string}}
    end
  end

  describe "walk/2 — keyword schemas" do
    test "walks keyword-list-shaped schema" do
      schema = [name: {:required, :string}, age: :integer]

      result =
        Peri.walk(schema, fn
          {:required, t} -> {:cont, t}
          other -> {:cont, other}
        end)

      assert result == [name: :string, age: :integer]
    end

    test "drops a keyword field" do
      schema = [name: :string, secret: :string]

      result =
        Peri.walk(schema, fn
          {:field, :secret, _} -> :drop
          other -> {:cont, other}
        end)

      assert result == [name: :string]
    end
  end

  describe "walk/2 — invalid callback returns" do
    test "raises on unexpected return value at type-expr position" do
      assert_raise ArgumentError, ~r/must return/, fn ->
        Peri.walk(%{x: :string}, fn _ -> :nope end)
      end
    end

    test "raises on non-field {:cont, _} at field position" do
      assert_raise ArgumentError, ~r/must return \{:cont, \{:field/, fn ->
        Peri.walk(%{x: :string}, fn
          {:field, _, _} -> {:cont, :string}
          other -> {:cont, other}
        end)
      end
    end
  end

  describe "walk/2 — :multi branches" do
    test "transforms inside each branch" do
      schema = %{
        shape:
          {:multi, :type,
           %{
             "circle" => %{type: {:required, :string}, r: {:required, :float}},
             "rect" => %{type: {:required, :string}, w: :float}
           }}
      }

      result =
        Peri.walk(schema, fn
          {:required, t} -> {:cont, t}
          other -> {:cont, other}
        end)

      assert result == %{
               shape:
                 {:multi, :type,
                  %{
                    "circle" => %{type: :string, r: :float},
                    "rect" => %{type: :string, w: :float}
                  }}
             }
    end
  end

  describe "walk/2 — composes with Peri.validate" do
    test "make-optional + validate accepts data missing previously-required keys" do
      schema = %{name: {:required, :string}, age: {:required, :integer}}

      relaxed =
        Peri.walk(schema, fn
          {:required, t} -> {:cont, t}
          other -> {:cont, other}
        end)

      assert {:ok, _} = Peri.validate(relaxed, %{})
      assert {:error, _} = Peri.validate(schema, %{})
    end

    test "strip-fields + validate filters out dropped key from accepted data" do
      schema = %{name: {:required, :string}, secret: :string}

      public =
        Peri.walk(schema, fn
          {:field, :secret, _} -> :drop
          other -> {:cont, other}
        end)

      data = %{name: "x", secret: "shh"}
      assert {:ok, %{name: "x"}} = Peri.validate(public, data)
    end
  end
end
