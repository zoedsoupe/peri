defmodule Peri.Error do
  defstruct [:path, :expected, :actual, :message, :errors]
end
