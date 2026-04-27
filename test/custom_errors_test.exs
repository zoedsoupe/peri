defmodule Peri.CustomErrorsTest do
  use ExUnit.Case, async: true

  import Peri

  defmodule Msgs do
    def email_msg(%Peri.Error{} = err), do: "email is invalid (was: #{inspect(err.content)})"
    def with_args(%Peri.Error{}, prefix), do: "#{prefix}: bad value"
  end

  defschema(:user, %{
    age: {:integer, gte: 18, error: "must be adult"},
    email: {:required, :string, [error: {Msgs, :email_msg, []}]},
    nickname: {:string, [min: 3, error: "too short"]}
  })

  describe "field-level error overrides" do
    test "static string overrides constraint error" do
      assert {:error, [%Peri.Error{path: [:age], message: "must be adult"}]} =
               user(%{age: 10, email: "a@b.io"})
    end

    test "MFA override receives the Peri.Error and returns string" do
      assert {:error, errors} = user(%{email: 123})
      err = Enum.find(errors, &(&1.key == :email))
      assert err
      assert is_binary(err.message)
      assert err.message =~ "email is invalid"
      assert err.message =~ "(was: "
    end

    test "MFA override fires when required field is missing" do
      assert {:error, errors} = user(%{age: 20})
      err = Enum.find(errors, &(&1.key == :email))
      assert err.message =~ "email is invalid"
    end

    test "static string override on nested string constraint" do
      assert {:error, [%Peri.Error{path: [:nickname], message: "too short"}]} =
               user(%{age: 20, email: "a@b.io", nickname: "ab"})
    end

    test "no override means default message" do
      schema = %{age: {:integer, gte: 18}}

      assert {:error, [%Peri.Error{path: [:age], message: msg}]} =
               Peri.validate(schema, %{age: 5})

      refute msg == "must be adult"
    end
  end

  describe "validate_schema" do
    test "rejects non-string non-MFA error opt" do
      schema = %{x: {:integer, [error: 123]}}
      assert {:error, _} = Peri.validate_schema(schema)
    end

    test "accepts static string" do
      schema = %{x: {:integer, [error: "bad"]}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "accepts MFA" do
      schema = %{x: {:integer, [error: {Mod, :fun, []}]}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "{:required, type, [error: msg]} valid" do
      schema = %{x: {:required, :string, [error: "needed"]}}
      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end
  end

  describe "Peri.Error.traverse_errors/2" do
    test "translates flat errors" do
      {:error, errors} = user(%{age: 10, email: "a@b.io"})

      translated =
        Peri.Error.traverse_errors(errors, fn err ->
          "[translated] #{err.message}"
        end)

      assert Enum.all?(translated, fn err -> String.starts_with?(err.message, "[translated]") end)
    end

    test "translates nested errors at leaves" do
      schema = %{outer: %{inner: {:required, :string, [error: "leaf-msg"]}}}
      {:error, errors} = Peri.validate(schema, %{outer: %{}})

      translated =
        Peri.Error.traverse_errors(errors, fn err ->
          "x_" <> err.message
        end)

      [%Peri.Error{errors: [leaf]}] = translated
      assert leaf.message == "x_leaf-msg"
    end

    test "non-string callback result coerces to string" do
      {:error, errors} = user(%{age: 10, email: "a@b.io"})
      translated = Peri.Error.traverse_errors(errors, fn _ -> :ok end)
      assert Enum.all?(translated, fn err -> err.message == "ok" end)
    end
  end
end
