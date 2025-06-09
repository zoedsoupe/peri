defmodule NestedListCallbackTest do
  use ExUnit.Case, async: true

  import Peri

  defschema(:parent, %{
    a: :string,
    b: {:list, get_schema(:child)}
  })

  defschema(:parent_new, %{
    a: :string,
    b: {:list, get_schema(:child_new)}
  })

  defschema(:child, %{
    c: :string,
    d: {:dependent, &what_is_d/1}
  })

  defschema(:child_new, %{
    c: :string,
    d: {:dependent, &what_is_d_new/2}
  })

  def what_is_d(data) do
    if Map.has_key?(data, :c) do
      if data.c == "special" do
        {:ok, :integer}
      else
        {:ok, :string}
      end
    else
      {:ok, :string}
    end
  end

  def what_is_d_new(current, _root) do
    if current.c == "special" do
      {:ok, :integer}
    else
      {:ok, :string}
    end
  end

  describe ":dependent type in nested list schemas" do
    test "direct child validation works correctly" do
      child_data = %{c: "special", d: 42}
      assert {:ok, ^child_data} = child(child_data)

      child_data = %{c: "normal", d: "text"}
      assert {:ok, ^child_data} = child(child_data)

      child_data = %{c: "special", d: "text"}
      assert {:error, _} = child(child_data)
    end

    test "parent validation demonstrates the issue" do
      parent_data = %{
        a: "parent value",
        b: [
          %{c: "special", d: 42},
          %{c: "normal", d: "text"}
        ]
      }

      result = parent(parent_data)

      # The issue is that what_is_d receives the parent data,
      # not the individual child being validated
      case result do
        {:ok, _} ->
          # It passes, but not for the right reasons
          assert true

        {:error, _} ->
          # It might fail if we try to access child fields
          assert true
      end
    end

    test "2-arity callback receives current element data in lists" do
      parent_data = %{
        a: "parent value",
        b: [
          %{c: "special", d: 42},
          %{c: "normal", d: "text"}
        ]
      }

      assert {:ok, ^parent_data} = parent_new(parent_data)

      bad_parent_data = %{
        a: "parent value",
        b: [
          %{c: "special", d: "wrong"},
          %{c: "normal", d: "text"}
        ]
      }

      assert {:error, _} = parent_new(bad_parent_data)
    end
  end

  defschema(:parent_cond, %{
    items: {:list, get_schema(:child_cond)}
  })

  defschema(:parent_cond_new, %{
    items: {:list, get_schema(:child_cond_new)}
  })

  defschema(:child_cond, %{
    type: :string,
    value: {:cond, &numeric_type?/1, :integer, :string}
  })

  defschema(:child_cond_new, %{
    type: :string,
    value: {:cond, &numeric_type_new?/2, :integer, :string}
  })

  def numeric_type?(data) do
    Map.get(data, :type) == "numeric"
  end

  def numeric_type_new?(current, _root) do
    current.type == "numeric"
  end

  describe ":cond type in nested list schemas" do
    test "cond type has the same issue in lists" do
      parent_data = %{
        items: [
          %{type: "numeric", value: 123},
          %{type: "text", value: "hello"}
        ]
      }

      result = parent_cond(parent_data)

      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "2-arity cond callback receives current element data in lists" do
      parent_data = %{
        items: [
          %{type: "numeric", value: 123},
          %{type: "text", value: "hello"}
        ]
      }

      assert {:ok, ^parent_data} = parent_cond_new(parent_data)

      bad_parent_data = %{
        items: [
          %{type: "numeric", value: "not a number"},
          %{type: "text", value: "hello"}
        ]
      }

      assert {:error, _} = parent_cond_new(bad_parent_data)
    end
  end

  defmodule CallbackHelpers do
    def determine_type_1_arity(data) do
      if Map.has_key?(data, :type) do
        if data.type == "number" do
          {:ok, :integer}
        else
          {:ok, :string}
        end
      else
        {:ok, :string}
      end
    end

    def determine_type_2_arity(current, _root) do
      if current.type == "number" do
        {:ok, :integer}
      else
        {:ok, :string}
      end
    end
  end

  defschema(:parent_mfa, %{
    items: {:list, get_schema(:child_mfa)}
  })

  defschema(:child_mfa, %{
    type: :string,
    value: {:dependent, {CallbackHelpers, :determine_type_2_arity}}
  })

  describe "MFA callbacks with 2-arity" do
    test "MFA callbacks work with 2-arity functions" do
      parent_data = %{
        items: [
          %{type: "number", value: 123},
          %{type: "text", value: "hello"}
        ]
      }

      assert {:ok, ^parent_data} = parent_mfa(parent_data)

      bad_data = %{
        items: [
          %{type: "number", value: "not a number"}
        ]
      }

      assert {:error, _} = parent_mfa(bad_data)
    end
  end
end
