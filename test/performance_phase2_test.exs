defmodule Peri.PerformancePhase2Test do
  use ExUnit.Case, async: true

  defmodule Record do
    defstruct [:id, :extra]
  end

  test "strict traversal preserves falsy values and applies nested conversions" do
    schema = %{
      "enabled" => {:boolean, {:default, true}},
      count: {:coerce, :string, :integer},
      note: :any,
      entries:
        {:list,
         %{
           active: :boolean,
           quantity: {:integer, {:transform, &(&1 + 1)}}
         }}
    }

    data = %{
      "enabled" => false,
      "count" => "0",
      "note" => nil,
      "entries" => [%{"active" => false, "quantity" => 1, "ignored" => true}],
      "ignored" => true
    }

    assert {:ok,
            %{
              "enabled" => false,
              count: 0,
              note: nil,
              entries: [%{active: false, quantity: 2}]
            }} = Peri.decode(schema, data)

    assert {:ok, permissive} = Peri.decode(schema, data, mode: :permissive)
    assert permissive["ignored"]
    assert [%{"ignored" => true} = entry] = permissive[:entries]
    assert entry["active"] == false
    assert entry[:quantity] == 2
  end

  test "strict callbacks receive the unfiltered root and structs keep their fields" do
    schema = %{
      prefix: :string,
      label: {:string, {:transform, fn value, root -> root.prefix <> value end}}
    }

    assert {:ok, %{label: "raw-value"}} =
             Peri.validate(schema, %{prefix: "raw-", label: "value", ignored: true})

    assert {:ok, %Record{id: 1, extra: "kept"}} =
             Peri.validate(%{id: :integer}, %Record{id: 1, extra: "kept"})
  end

  test "keyword schemas preserve sequential validation for duplicate keys" do
    schema = [
      value: {:integer, {:transform, &(&1 + 1)}},
      value: {:integer, {:transform, &(&1 + 1)}}
    ]

    assert {:ok, [value: 3]} = Peri.validate(schema, value: 1)
  end
end
