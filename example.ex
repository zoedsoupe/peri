defmodule Example do
  import Peri

  defschema :user, %{
    name: :string,
    foo: {:either, {%{bar: :string}, :string}},
    data: {:list, %{baz: :string}}
  }
end
