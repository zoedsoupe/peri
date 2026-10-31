defmodule Peri.ErrorEncodingTest do
  use ExUnit.Case, async: true

  if Code.ensure_loaded?(Jason) do
    test "encodes errors with Jason when Jason is available" do
      error = %Peri.Error{message: "invalid"}

      assert %{"message" => "invalid"} = error |> Jason.encode!() |> Jason.decode!()
    end
  end

  if Code.ensure_loaded?(JSON) do
    test "encodes errors with the native JSON module when available" do
      error = %Peri.Error{message: "invalid"}

      assert %{"message" => "invalid"} = error |> JSON.encode!() |> JSON.decode!()
    end
  end
end
