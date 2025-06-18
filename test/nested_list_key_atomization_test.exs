defmodule NestedListKeyAtomizationTest do
  use ExUnit.Case, async: true

  describe "nested schemas in list with string keys" do
    test "atomizes keys in nested schemas within lists" do
      schema = %{
        id: {:required, :string},
        value: {:required, :integer},
        stats: %{
          foo: {:required, :integer},
          bar: :integer
        },
        replies:
          {:list,
           %{
             content: {:required, :string},
             likes: {:required, :integer},
             author: %{
               name: {:required, :string}
             }
           }}
      }

      input = %{
        "id" => "1234",
        "value" => 52,
        "stats" => %{"foo" => 5},
        "replies" => [
          %{
            "content" => "blah blah",
            "likes" => 1,
            "author" => %{"name" => "Jane Doe"}
          }
        ]
      }

      assert {:ok, result} = Peri.validate(schema, input)

      assert result.id == "1234"
      assert result.value == 52
      assert result.stats.foo == 5

      [reply] = result.replies
      assert reply.content == "blah blah"
      assert reply.likes == 1
      assert reply.author.name == "Jane Doe"

      refute Map.has_key?(reply, "content")
      refute Map.has_key?(reply, "likes")
      refute Map.has_key?(reply, "author")

      refute Map.has_key?(reply.author, "name")
    end

    test "multiple nested levels in lists all get atomized" do
      schema = %{
        items:
          {:list,
           %{
             id: :string,
             nested: %{
               name: :string,
               deep: %{
                 value: :integer
               }
             }
           }}
      }

      input = %{
        "items" => [
          %{
            "id" => "1",
            "nested" => %{
              "name" => "test",
              "deep" => %{"value" => 42}
            }
          }
        ]
      }

      assert {:ok, result} = Peri.validate(schema, input)

      [item] = result.items
      assert item.id == "1"
      assert item.nested.name == "test"
      assert item.nested.deep.value == 42

      refute Map.has_key?(item, "id")
      refute Map.has_key?(item, "nested")
      refute Map.has_key?(item.nested, "name")
      refute Map.has_key?(item.nested, "deep")
      refute Map.has_key?(item.nested.deep, "value")
    end

    test "preserves atom keys when input already has atoms" do
      schema = %{
        replies:
          {:list,
           %{
             content: :string,
             author: %{
               name: :string
             }
           }}
      }

      input = %{
        replies: [
          %{
            content: "hello",
            author: %{name: "Alice"}
          }
        ]
      }

      assert {:ok, result} = Peri.validate(schema, input)

      [reply] = result.replies
      assert reply.content == "hello"
      assert reply.author.name == "Alice"
    end

    test "mixed atom and string keys in list elements" do
      schema = %{
        items:
          {:list,
           %{
             id: :string,
             meta: %{
               key: :string
             }
           }}
      }

      input = %{
        "items" => [
          %{
            "id" => "atom-key",
            "meta" => %{"key" => "string-key"}
          }
        ]
      }

      assert {:ok, result} = Peri.validate(schema, input)

      [item] = result.items
      assert item.id == "atom-key"
      assert item.meta.key == "string-key"

      refute Map.has_key?(item, "id")
      refute Map.has_key?(item, "meta")
      refute Map.has_key?(item.meta, "key")
    end
  end
end
