defmodule Peri.CoerceTest.CustomCoercions do
  @moduledoc false

  def parse_amount(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> {:ok, int * 100}
      _other -> :error
    end
  end

  def parse_amount(_val), do: :error

  def parse_with_args(val, factor) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> {:ok, int * factor}
      _other -> :error
    end
  end

  def parse_with_args(_val, _factor), do: :error
end

defmodule Peri.CoerceTest do
  use ExUnit.Case, async: true

  import Peri

  doctest Peri, only: [decode: 3, encode: 3]

  alias Peri.CoerceTest.CustomCoercions

  defschema(:pagination, %{
    page: {:coerce, :string, :integer},
    per_page: {:coerce, :string, :integer},
    active: {:coerce, :string, :boolean}
  })

  defschema(:wire_params, %{
    "page" => {:coerce, :string, :integer},
    "since" => {:coerce, :string, :date}
  })

  defschema(:nested_coerce, %{
    user: %{
      age: {:coerce, :string, :integer}
    }
  })

  defschema(:list_coerce, %{
    scores: {:list, {:coerce, :string, :integer}}
  })

  defschema(:custom_fun_coerce, %{
    amount: {:coerce, &parse_currency/1, :integer}
  })

  defschema(:custom_mfa_coerce, %{
    amount: {:coerce, {CustomCoercions, :parse_amount}, :integer},
    factored: {:coerce, {CustomCoercions, :parse_with_args, [10]}, :integer}
  })

  defschema(:constrained_coerce, %{
    age: {:coerce, :string, {:integer, {:gte, 18}}}
  })

  defschema(:required_coerce, %{
    page: {:required, {:coerce, :string, :integer}}
  })

  defschema(:default_coerce, %{
    page: {{:coerce, :string, :integer}, {:default, "5"}}
  })

  defschema(:encode_opt_field, %{
    name: {:string, {:encode, &String.upcase/1}}
  })

  defschema(:transform_field, %{
    number: {:integer, {:transform, &(&1 * 2)}}
  })

  defschema(:custom_encode_opt, %{
    page: {:coerce, :string, :integer, encode: &"page-#{&1}"}
  })

  defp parse_currency("$" <> rest), do: parse_currency(rest)

  defp parse_currency(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> {:ok, int}
      _other -> :error
    end
  end

  defp parse_currency(_val), do: :error

  describe "built-in string coercions" do
    test "coerces string params into typed data" do
      params = %{"page" => "2", "per_page" => "50", "active" => "true"}
      assert {:ok, %{page: 2, per_page: 50, active: true}} = pagination(params)
    end

    test "float coercion accepts integers and floats" do
      assert {:ok, %{val: 1.0}} =
               Peri.validate(%{val: {:coerce, :string, :float}}, %{"val" => "1"})

      assert {:ok, %{val: 1.5}} =
               Peri.validate(%{val: {:coerce, :string, :float}}, %{"val" => "1.5"})
    end

    test "boolean coercion accepts only true and false" do
      schema = %{flag: {:coerce, :string, :boolean}}
      assert {:ok, %{flag: true}} = Peri.validate(schema, %{"flag" => "true"})
      assert {:ok, %{flag: false}} = Peri.validate(schema, %{"flag" => "false"})

      assert {:error,
              [
                %Peri.Error{
                  path: [:flag],
                  message: "cannot coerce \"yes\" from :string to :boolean"
                }
              ]} = Peri.validate(schema, %{"flag" => "yes"})
    end

    test "atom coercion uses existing atoms only" do
      schema = %{role: {:coerce, :string, :atom}}
      assert {:ok, %{role: :admin}} = Peri.validate(schema, %{"role" => "admin"})

      assert {:error, [%Peri.Error{path: [:role], message: message}]} =
               Peri.validate(schema, %{"role" => "nonexistent_atom_xyz_123"})

      assert message =~ "cannot coerce"
    end

    test "date and time coercions parse ISO 8601" do
      schema = %{
        date: {:coerce, :string, :date},
        time: {:coerce, :string, :time},
        naive: {:coerce, :string, :naive_datetime},
        dt: {:coerce, :string, :datetime}
      }

      data = %{
        "date" => "2024-03-15",
        "time" => "10:30:00",
        "naive" => "2024-03-15T10:30:00",
        "dt" => "2024-03-15T10:30:00Z"
      }

      assert {:ok,
              %{
                date: ~D[2024-03-15],
                time: ~T[10:30:00],
                naive: ~N[2024-03-15 10:30:00],
                dt: %DateTime{}
              }} = Peri.validate(schema, data)
    end

    test "rejects partial integer parses" do
      schema = %{page: {:coerce, :string, :integer}}

      assert {:error,
              [
                %Peri.Error{
                  path: [:page],
                  message: "cannot coerce \"12ab\" from :string to :integer"
                }
              ]} = Peri.validate(schema, %{"page" => "12ab"})
    end

    test "rejects invalid ISO dates" do
      schema = %{date: {:coerce, :string, :date}}

      assert {:error,
              [
                %Peri.Error{
                  path: [:date],
                  message: "cannot coerce \"2024-13-45\" from :string to :date"
                }
              ]} = Peri.validate(schema, %{"date" => "2024-13-45"})
    end

    test "values already matching the target type pass through unchanged" do
      assert {:ok, %{page: 2, per_page: 50, active: true}} =
               pagination(%{page: 2, per_page: 50, active: true})

      schema = %{date: {:coerce, :string, :date}}
      assert {:ok, %{date: ~D[2024-03-15]}} = Peri.validate(schema, %{date: ~D[2024-03-15]})
    end

    test "values matching neither target nor source return the target error" do
      schema = %{page: {:coerce, :string, :integer}}

      assert {:error, [%Peri.Error{path: [:page], message: message}]} =
               Peri.validate(schema, %{"page" => 1.5})

      assert message =~ "expected type of :integer"
    end
  end

  describe "nested and list coercion" do
    test "coerces inside nested schemas" do
      assert {:ok, %{user: %{age: 30}}} = nested_coerce(%{"user" => %{"age" => "30"}})
    end

    test "coerces each element of a list" do
      assert {:ok, %{scores: [1, 2, 3]}} = list_coerce(%{"scores" => ["1", "2", "3"]})
    end

    test "reports errors for elements that cannot be coerced" do
      assert {:error, [%Peri.Error{path: [:scores], message: message}]} =
               list_coerce(%{"scores" => ["1", "nope"]})

      assert message =~ "cannot coerce"
    end
  end

  describe "custom sources" do
    test "1-arity function source" do
      assert {:ok, %{amount: 2500}} = custom_fun_coerce(%{"amount" => "$2500"})

      assert {:error, [%Peri.Error{path: [:amount], message: message}]} =
               custom_fun_coerce(%{"amount" => "$abc"})

      assert message =~ "cannot coerce"
    end

    test "MFA source with and without args" do
      assert {:ok, %{amount: 4200, factored: 420}} =
               custom_mfa_coerce(%{"amount" => "42", "factored" => "42"})

      assert {:error, [%Peri.Error{path: [:amount], message: message}]} =
               custom_mfa_coerce(%{"amount" => "x", "factored" => "42"})

      assert message =~ "cannot coerce"
    end
  end

  describe "target constraints" do
    test "constraints on the target are enforced after coercion" do
      assert {:ok, %{age: 21}} = constrained_coerce(%{"age" => "21"})

      assert {:error,
              [
                %Peri.Error{
                  path: [:age],
                  message: "should be greater then or equal to 18"
                }
              ]} = constrained_coerce(%{"age" => "17"})
    end
  end

  describe "required and defaults" do
    test "required coerce fields reject missing values" do
      assert {:error, [%Peri.Error{path: [:page], message: message}]} = required_coerce(%{})
      assert message =~ "is required"
    end

    test "required coerce fields coerce present values" do
      assert {:ok, %{page: 7}} = required_coerce(%{"page" => "7"})
    end

    test "defaults flow through coercion" do
      assert {:ok, %{page: 5}} = default_coerce(%{})
      assert {:ok, %{page: 9}} = default_coerce(%{"page" => "9"})
    end
  end

  describe "encode/3" do
    test "encodes typed data back to the wire representation" do
      assert {:ok, %{"page" => "2", "since" => "2024-03-15"}} =
               Peri.encode(wire_params_schema(), %{"page" => 2, "since" => ~D[2024-03-15]})
    end

    test "encode(decode(x)) round-trips string-sourced data" do
      wire = %{"page" => "2", "since" => "2024-03-15"}
      schema = wire_params_schema()

      assert {:ok, decoded} = Peri.decode(schema, wire)
      assert decoded == %{"page" => 2, "since" => ~D[2024-03-15]}
      assert {:ok, encoded} = Peri.encode(schema, decoded)
      assert encoded == wire
    end

    test "encode validates target types and does not coerce" do
      assert {:error, [%Peri.Error{path: [:page]}]} =
               Peri.encode(pagination_schema(), %{"page" => "2"})
    end

    test "{:encode, fun} is applied on encode and ignored on validate" do
      assert {:ok, %{name: "hello"}} = Peri.validate(encode_opt_schema(), %{name: "hello"})
      assert {:ok, %{name: "HELLO"}} = Peri.encode(encode_opt_schema(), %{name: "hello"})
    end

    test "{:transform, fun} is applied on validate and skipped on encode" do
      assert {:ok, %{number: 8}} = Peri.validate(transform_schema(), %{number: 4})
      assert {:ok, %{number: 4}} = Peri.encode(transform_schema(), %{number: 4})
    end

    test "custom encode: opt overrides the built-in reverse" do
      assert {:ok, %{page: "page-3"}} = Peri.encode(custom_encode_schema(), %{page: 3})
    end

    test "custom source without encode opt passes the value through on encode" do
      schema = %{amount: {:coerce, {CustomCoercions, :parse_amount}, :integer}}
      assert {:ok, %{amount: 42}} = Peri.encode(schema, %{amount: 42})
    end
  end

  describe "decode/3" do
    test "is an alias of validate/3" do
      schema = pagination_schema()

      assert {:ok, %{page: 2, active: true}} =
               Peri.decode(schema, %{"page" => "2", "active" => "true"})

      assert {:ok, %{page: 2}} = Peri.decode(schema, %{page: 2})
    end
  end

  describe "schema-time validation" do
    test "accepts valid coerce definitions" do
      assert {:ok, _} = Peri.validate_schema(%{x: {:coerce, :string, :integer}})
      assert {:ok, _} = Peri.validate_schema(%{x: {:coerce, :string, {:integer, {:gte, 18}}}})
      assert {:ok, _} = Peri.validate_schema(%{x: {:coerce, fn _ -> :error end, :any}})

      assert {:ok, _} =
               Peri.validate_schema(%{x: {:coerce, {CustomCoercions, :parse_amount}, :integer}})

      assert {:ok, _} =
               Peri.validate_schema(%{x: {:coerce, :string, :integer, encode: &to_string/1}})
    end

    test "rejects unsupported sources" do
      assert {:error, [%Peri.Error{path: [:x], message: message}]} =
               Peri.validate_schema(%{x: {:coerce, :integer, :string}})

      assert message =~ "expected coerce source"
    end

    test "rejects unsupported built-in targets" do
      assert {:error, [%Peri.Error{path: [:x], message: message}]} =
               Peri.validate_schema(%{x: {:coerce, :string, :map}})

      assert message =~ "expected coerce target for :string source"
    end

    test "rejects invalid nested target types" do
      assert {:error, [%Peri.Error{path: [:x]}]} =
               Peri.validate_schema(%{x: {:coerce, fn v -> {:ok, v} end, :not_a_type}})
    end

    test "rejects unknown or invalid coerce opts" do
      assert {:error, [%Peri.Error{path: [:x], message: message}]} =
               Peri.validate_schema(%{x: {:coerce, :string, :integer, foo: 1}})

      assert message =~ "unknown coerce opts"

      assert {:error, [%Peri.Error{path: [:x], message: message}]} =
               Peri.validate_schema(%{x: {:coerce, :string, :integer, encode: "up"}})

      assert message =~ "expected encode: opt"

      assert {:error, [%Peri.Error{path: [:x], message: message}]} =
               Peri.validate_schema(%{x: {:coerce, :string, :integer, "encode"}})

      assert message =~ "keyword list"

      assert {:error, [%Peri.Error{path: [:x], message: message}]} =
               Peri.validate_schema(%{x: {:coerce, :string, :integer, [:encode]}})

      assert message =~ "keyword list"
    end
  end

  describe "tooling integration" do
    test "json schema output uses the target type" do
      assert %{"properties" => %{"page" => %{"type" => "integer"}}} =
               Peri.to_json_schema(%{page: {:coerce, :string, :integer}})
    end

    test "walker recurses into the coerce target" do
      schema = %{page: {:coerce, :string, {:required, :integer}}}

      assert %{page: {:coerce, :string, :integer}} =
               Peri.walk(schema, fn
                 {:required, t} -> {:cont, t}
                 other -> {:cont, other}
               end)
    end

    test "generation produces target-typed values" do
      {:ok, stream} = Peri.generate(%{page: {:coerce, :string, :integer}})
      assert [%{page: page}] = Enum.take(stream, 1)
      assert is_integer(page)
    end
  end

  defp pagination_schema, do: get_schema(:pagination)
  defp wire_params_schema, do: get_schema(:wire_params)
  defp encode_opt_schema, do: get_schema(:encode_opt_field)
  defp transform_schema, do: get_schema(:transform_field)
  defp custom_encode_schema, do: get_schema(:custom_encode_opt)
end
