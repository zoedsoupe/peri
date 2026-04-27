defmodule Peri.MetaTest do
  use ExUnit.Case, async: true

  import Peri

  defschema(
    :user,
    %{
      email: {:meta, {:required, :string}, doc: "Login email", example: "a@b.io"},
      age: {:meta, {:integer, gte: 0}, description: "Years"}
    },
    title: "User",
    description: "Account holder",
    custom_key: "anything"
  )

  defschema(:nested, %{
    profile: {:meta, %{name: {:required, :string}, bio: :string}, doc: "User profile"}
  })

  defschema(:plain, %{name: :string})

  describe "{:meta, type, opts} wrapper" do
    test "passthrough validation succeeds for valid data" do
      assert {:ok, %{email: "a@b.io", age: 30}} =
               user(%{email: "a@b.io", age: 30})
    end

    test "wrapped :required still enforced" do
      assert {:error, [%Peri.Error{path: [:email]}]} = user(%{age: 30})
    end

    test "wrapped constraints still enforced" do
      assert {:error, [%Peri.Error{path: [:age]}]} =
               user(%{email: "a@b.io", age: -1})
    end

    test "wrapped type mismatch errors normally" do
      assert {:error, [%Peri.Error{path: [:age]}]} =
               user(%{email: "a@b.io", age: "thirty"})
    end

    test "nested schema inside meta validates and filters" do
      assert {:ok, %{profile: %{name: "Jane", bio: "hi"}}} =
               nested(%{profile: %{name: "Jane", bio: "hi", drop: "x"}})
    end

    test "nested schema inside meta enforces required" do
      assert {:error,
              [
                %Peri.Error{
                  path: [:profile],
                  errors: [%Peri.Error{path: [:profile, :name]}]
                }
              ]} = nested(%{profile: %{bio: "hi"}})
    end

    test "validate_schema accepts meta wrapper" do
      schema = %{x: {:meta, :integer, doc: "n"}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "validate_schema rejects non-keyword meta opts" do
      schema = %{x: {:meta, :integer, "not a keyword"}}
      assert {:error, _} = Peri.validate_schema(schema)
    end
  end

  describe "defschema schema-level meta opts" do
    test "blessed keys preserved on __schema_meta__" do
      meta = __MODULE__.__schema_meta__(:user)
      assert Keyword.get(meta, :title) == "User"
      assert Keyword.get(meta, :description) == "Account holder"
    end

    test "user keys preserved opaquely" do
      meta = __MODULE__.__schema_meta__(:user)
      assert Keyword.get(meta, :custom_key) == "anything"
    end

    test "validation opts excluded from meta" do
      defmodule WithMode do
        import Peri
        defschema(:s, %{n: :integer}, mode: :permissive, title: "S")
      end

      assert WithMode.__schema_meta__(:s) == [title: "S"]
      assert {:ok, %{n: 1, extra: "k"}} = WithMode.s(%{n: 1, extra: "k"})
    end

    test "schema with no meta returns empty list" do
      assert plain(%{name: "x"}) == {:ok, %{name: "x"}}
      assert __MODULE__.__schema_meta__(:plain) == []
    end
  end

  if Code.ensure_loaded?(StreamData) do
    describe "Peri.Generatable with meta" do
      test "unwraps meta and generates inner type" do
        schema = %{n: {:meta, :integer, doc: "n"}}
        {:ok, stream} = Peri.generate(schema)
        [sample] = Enum.take(stream, 1)
        assert is_integer(sample.n)
      end
    end
  end

  if Code.ensure_loaded?(Ecto) do
    describe "Peri.Ecto with meta" do
      test "to_changeset! unwraps meta wrapper" do
        schema = %{
          email: {:meta, {:required, :string}, doc: "Login"},
          age: {:meta, :integer, description: "Years"}
        }

        cs = Peri.to_changeset!(schema, %{email: "a@b.io", age: 30})
        assert cs.valid?
        assert cs.changes == %{email: "a@b.io", age: 30}
      end

      test "meta-wrapped required is enforced via Ecto" do
        schema = %{email: {:meta, {:required, :string}, doc: "Login"}}
        cs = Peri.to_changeset!(schema, %{})
        refute cs.valid?
        assert {"can't be blank", _} = cs.errors[:email]
      end
    end
  end
end
