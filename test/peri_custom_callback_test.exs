defmodule PeriCustomCallbackTest do
  use ExUnit.Case, async: true

  defmodule Callbacks do
    def original_root?(value, root) do
      if value in ["nested", "item"] and root.amount == "17" and
           root.ignored == "not retained" do
        :ok
      else
        {:error, "callback did not receive the original root", []}
      end
    end

    def false_root?(false, %{amount: "17"}), do: :ok
    def false_root?(_value, _root), do: {:error, "expected false and original root", []}

    def mfa_root?("item", %{source: "original"}), do: :ok
    def mfa_root?(_value, _root), do: {:error, "MFA did not receive original root", []}

    def prefer_value("value"), do: :ok
    def prefer_value(_value, _root), do: {:error, "root arity should not be preferred", []}

    def prefer_args("value", :legacy), do: :ok

    def prefer_args(_value, _root, :legacy),
      do: {:error, "root args arity should not be preferred", []}

    def root_args("value", %{source: "original"}, :root), do: :ok
    def root_args(_value, _root, _arg), do: {:error, "MFA did not receive root and args", []}

    def invalid_result(_value) do
      {:error, "custom rejection", [reason: :invalid, __error_override__: "custom override"]}
    end
  end

  test "2-arity callbacks receive current values and the original root through nesting and lists" do
    schema = %{
      amount: {:coerce, :string, :integer},
      nested: %{value: {:custom, &Callbacks.original_root?/2}},
      items: {:list, %{value: {:custom, &Callbacks.original_root?/2}}},
      flag: {:custom, &Callbacks.false_root?/2}
    }

    data = %{
      amount: "17",
      nested: %{value: "nested"},
      items: [%{value: "item"}],
      flag: false,
      ignored: "not retained"
    }

    assert {:ok,
            %{amount: 17, nested: %{value: "nested"}, items: [%{value: "item"}], flag: false}} =
             Peri.validate(schema, data)
  end

  test "nil current values keep the existing optional-field behavior" do
    schema = %{value: {:custom, fn _value, _root -> {:error, "must not run", []} end}}

    assert {:ok, %{value: nil}} = Peri.validate(schema, %{value: nil})
  end

  test "MFA callbacks can receive the original root in list elements" do
    schema = %{items: {:list, {:custom, {Callbacks, :mfa_root?}}}}

    assert {:ok, %{items: ["item"], source: "original"}} =
             Peri.validate(schema, %{items: ["item"], source: "original"}, mode: :permissive)
  end

  test "MFA forms prefer value-only arities when both are exported" do
    assert {:ok, %{value: "value"}} =
             Peri.validate(%{value: {:custom, {Callbacks, :prefer_value}}}, %{value: "value"})

    assert {:ok, %{value: "value"}} =
             Peri.validate(
               %{value: {:custom, {Callbacks, :prefer_args, [:legacy]}}},
               %{value: "value"}
             )
  end

  test "MFA args form can pass the original root before extra arguments" do
    schema = %{value: {:custom, {Callbacks, :root_args, [:root]}}}

    assert {:ok, %{source: "original", value: "value"}} =
             Peri.validate(schema, %{source: "original", value: "value"}, mode: :permissive)
  end

  test "missing MFA exports return validation errors rather than raising" do
    assert {:error, [error]} =
             Peri.validate(%{value: {:custom, {String, :no_such_callback}}}, %{value: "value"})

    assert error.message =~ "expected String to export :no_such_callback/1 or :no_such_callback/2"

    assert {:error, [args_error]} =
             Peri.validate(
               %{value: {:custom, {String, :no_such_callback, [:arg]}}},
               %{value: "value"}
             )

    assert args_error.message =~
             "expected String to export :no_such_callback with arity from 2 to 3"
  end

  test "callback errors preserve their context and error override" do
    assert {:error, [error]} =
             Peri.validate(%{value: {:custom, &Callbacks.invalid_result/1}}, %{value: "value"})

    assert error.message == "custom override"
    assert error.content == %{reason: :invalid}
  end

  test "invalid callback arities and MFA contracts are rejected as schema definitions" do
    invalid_schemas = [
      %{value: {:custom, fn -> :ok end}},
      %{value: {:custom, fn _value, _root, _extra -> :ok end}},
      %{value: {:custom, {Callbacks, :prefer_args, :not_a_list}}}
    ]

    for schema <- invalid_schemas do
      assert {:error, [_error]} = Peri.validate_schema(schema)
    end
  end
end
