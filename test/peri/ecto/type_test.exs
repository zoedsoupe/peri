defmodule Peri.Ecto.TypeTest do
  use ExUnit.Case, async: true

  alias Peri.Ecto.Type

  describe "Type.from/1" do
    test "converts basic Peri types to Ecto types" do
      assert Type.from(:any) == Peri.Ecto.Type.Any
      assert Type.from(:pid) == Peri.Ecto.Type.PID
      assert Type.from(:atom) == Peri.Ecto.Type.Atom
      assert Type.from(:datetime) == :utc_datetime
      assert Type.from(:string) == :string
      assert Type.from(:integer) == :integer
      assert Type.from(:float) == :float
      assert Type.from(:boolean) == :boolean
    end

    test "converts list types" do
      assert Type.from({:list, :string}) == {:array, :string}
      assert Type.from({:list, :integer}) == {:array, :integer}
      assert Type.from({:list, {:list, :string}}) == {:array, {:array, :string}}
    end

    test "converts enum types" do
      # String enum
      string_enum = Type.from({:enum, ["active", "inactive"]})
      assert match?({:parameterized, {Ecto.Enum, _}}, string_enum)

      # Atom enum
      atom_enum = Type.from({:enum, [:admin, :user]})
      assert match?({:parameterized, {Ecto.Enum, _}}, atom_enum)
    end

    test "converts oneof types" do
      oneof = Type.from({:oneof, [:string, :integer]})
      assert match?({:parameterized, {Peri.Ecto.Type.OneOf, _}}, oneof)
    end

    test "converts either types" do
      either = Type.from({:either, {:string, :integer}})
      assert match?({:parameterized, {Peri.Ecto.Type.Either, _}}, either)
    end

    test "converts tuple types" do
      tuple = Type.from({:tuple, [:string, :integer]})
      assert match?({:parameterized, {Peri.Ecto.Type.Tuple, _}}, tuple)
    end

    test "raises for mixed enum types" do
      assert_raise Peri.Error, ~r/Ecto.Enum only accepts strings and atoms/, fn ->
        Type.from({:enum, ["string", :atom, 123]})
      end
    end
  end

  describe "Peri.Ecto.Type.PID" do
    test "casts valid PIDs" do
      pid = self()
      assert {:ok, ^pid} = Ecto.Type.cast(Type.PID, pid)
    end

    test "rejects non-PID values" do
      assert :error = Ecto.Type.cast(Type.PID, "not_a_pid")
      assert :error = Ecto.Type.cast(Type.PID, 123)
      assert :error = Ecto.Type.cast(Type.PID, :atom)
    end

    test "dumps and loads PIDs" do
      pid = self()
      assert {:ok, binary} = Ecto.Type.dump(Type.PID, pid)
      assert is_binary(binary)
      assert {:ok, ^pid} = Ecto.Type.load(Type.PID, binary)
    end

    test "type returns :string for database storage" do
      assert Type.PID.type() == :string
    end
  end

  describe "Peri.Ecto.Type.Atom" do
    test "casts valid atoms" do
      assert {:ok, :hello} = Ecto.Type.cast(Type.Atom, :hello)
      assert {:ok, :world} = Ecto.Type.cast(Type.Atom, :world)
    end

    test "rejects non-atom values" do
      assert :error = Ecto.Type.cast(Type.Atom, "string")
      assert :error = Ecto.Type.cast(Type.Atom, 123)
      assert :error = Ecto.Type.cast(Type.Atom, %{})
    end

    test "dumps atoms to strings and loads them back" do
      assert {:ok, "hello"} = Ecto.Type.dump(Type.Atom, :hello)
      assert {:ok, :hello} = Ecto.Type.load(Type.Atom, "hello")
    end

    test "type returns :string for database storage" do
      assert Type.Atom.type() == :string
    end
  end

  describe "Peri.Ecto.Type.Any" do
    test "casts any value" do
      assert {:ok, "string"} = Ecto.Type.cast(Type.Any, "string")
      assert {:ok, 123} = Ecto.Type.cast(Type.Any, 123)
      assert {:ok, :atom} = Ecto.Type.cast(Type.Any, :atom)
      assert {:ok, %{key: "value"}} = Ecto.Type.cast(Type.Any, %{key: "value"})
      assert {:ok, [1, 2, 3]} = Ecto.Type.cast(Type.Any, [1, 2, 3])
    end

    test "dumps and loads values unchanged" do
      values = ["string", 123, :atom, %{key: "value"}, [1, 2, 3]]

      for value <- values do
        assert {:ok, ^value} = Ecto.Type.dump(Type.Any, value)
        assert {:ok, ^value} = Ecto.Type.load(Type.Any, value)
      end
    end

    test "type returns :custom" do
      assert Type.Any.type() == :custom
    end
  end

  describe "Peri.Ecto.Type.Tuple" do
    test "casts valid tuples" do
      {:parameterized, {_, params}} = Type.from({:tuple, [:string, :integer]})
      
      assert {:ok, {"hello", 42}} = Type.Tuple.cast({"hello", 42}, params)
    end

    test "rejects tuples with wrong size" do
      {:parameterized, {_, params}} = Type.from({:tuple, [:string, :integer]})
      
      assert :error = Type.Tuple.cast({"hello"}, params)
      assert :error = Type.Tuple.cast({"hello", 42, "extra"}, params)
    end

    test "rejects tuples with wrong types" do
      {:parameterized, {_, params}} = Type.from({:tuple, [:string, :integer]})
      
      assert :error = Type.Tuple.cast({123, "string"}, params)
      assert :error = Type.Tuple.cast({"hello", "not_an_integer"}, params)
    end

    test "casts tuples with nested maps" do
      {:parameterized, {_, params}} = Type.from({:tuple, [:string, %{name: :string}]})
      
      assert {:ok, {"id", %{name: "John"}}} = Type.Tuple.cast({"id", %{name: "John"}}, params)
    end

    test "dumps tuples to maps and loads them back" do
      {:parameterized, {_, params}} = Type.from({:tuple, [:string, :integer]})
      tuple = {"hello", 42}
      
      assert {:ok, dumped} = Type.Tuple.dump(tuple, nil, params)
      assert dumped == %{0 => "hello", 1 => 42}
      
      assert {:ok, loaded} = Type.Tuple.load(dumped, nil, params)
      assert loaded == tuple
    end

    test "validates schema on init" do
      assert_raise Peri.Error, fn ->
        Type.Tuple.init(elements: [:invalid_type])
      end
    end
  end

  describe "Peri.Ecto.Type.Either" do
    test "casts values matching first type" do
      {:parameterized, {_, params}} = Type.from({:either, {:string, :integer}})
      
      assert {:ok, "hello"} = Type.Either.cast("hello", params)
    end

    test "casts values matching second type" do
      {:parameterized, {_, params}} = Type.from({:either, {:string, :integer}})
      
      assert {:ok, 42} = Type.Either.cast(42, params)
    end

    test "rejects values matching neither type" do
      {:parameterized, {_, params}} = Type.from({:either, {:string, :integer}})
      
      assert :error = Type.Either.cast(:atom, params)
      assert :error = Type.Either.cast(%{}, params)
    end

    test "casts either with map as first type" do
      {:parameterized, {_, params}} = Type.from({:either, {%{name: :string}, :integer}})
      
      assert {:ok, %{name: "John"}} = Type.Either.cast(%{name: "John"}, params)
      assert {:ok, 42} = Type.Either.cast(42, params)
    end

    test "casts either with map as second type" do
      {:parameterized, {_, params}} = Type.from({:either, {:string, %{id: :integer}}})
      
      assert {:ok, "text"} = Type.Either.cast("text", params)
      assert {:ok, %{id: 123}} = Type.Either.cast(%{id: 123}, params)
    end

    test "dumps and loads values" do
      {:parameterized, {_, params}} = Type.from({:either, {:string, :integer}})
      
      assert {:ok, "hello"} = Type.Either.dump("hello", nil, params)
      assert {:ok, 42} = Type.Either.dump(42, nil, params)
      
      assert {:ok, "hello"} = Type.Either.load("hello", nil, params)
      assert {:ok, 42} = Type.Either.load(42, nil, params)
    end

    test "validates schema on init" do
      assert_raise Peri.Error, fn ->
        Type.Either.init(values: {:invalid_type, :string})
      end
    end
  end

  describe "Peri.Ecto.Type.OneOf" do
    test "casts values matching any of the types" do
      {:parameterized, {_, params}} = Type.from({:oneof, [:string, :integer, :boolean]})
      
      assert {:ok, "hello"} = Type.OneOf.cast("hello", params)
      assert {:ok, 42} = Type.OneOf.cast(42, params)
      assert {:ok, true} = Type.OneOf.cast(true, params)
    end

    test "rejects values matching none of the types" do
      {:parameterized, {_, params}} = Type.from({:oneof, [:string, :integer, :boolean]})
      
      assert :error = Type.OneOf.cast(:atom, params)
      assert :error = Type.OneOf.cast(%{}, params)
      assert :error = Type.OneOf.cast([1, 2, 3], params)
    end

    test "casts oneof with map types" do
      {:parameterized, {_, params}} = Type.from({:oneof, [:string, %{id: :integer}]})
      
      assert {:ok, "text"} = Type.OneOf.cast("text", params)
      assert {:ok, %{id: 123}} = Type.OneOf.cast(%{id: 123}, params)
    end

    test "dumps and loads values" do
      {:parameterized, {_, params}} = Type.from({:oneof, [:string, :integer, :boolean]})
      
      values = ["hello", 42, true]
      
      for value <- values do
        assert {:ok, ^value} = Type.OneOf.dump(value, nil, params)
        assert {:ok, ^value} = Type.OneOf.load(value, nil, params)
      end
    end

    test "validates schema on init" do
      assert_raise Peri.Error, fn ->
        Type.OneOf.init(values: [:invalid_type])
      end
    end
  end

  describe "complex type combinations" do
    test "list of tuples" do
      list_of_tuples = Type.from({:list, {:tuple, [:string, :integer]}})
      assert match?({:array, {:parameterized, {Peri.Ecto.Type.Tuple, _}}}, list_of_tuples)
    end

    test "either with lists" do
      either_lists = Type.from({:either, {{:list, :string}, {:list, :integer}}})
      assert match?({:parameterized, {Peri.Ecto.Type.Either, _}}, either_lists)
    end

    test "nested type conversions" do
      complex = Type.from({:list, {:either, {:string, {:tuple, [:integer, :boolean]}}}})
      assert match?({:array, {:parameterized, {Peri.Ecto.Type.Either, _}}}, complex)
    end
  end
end