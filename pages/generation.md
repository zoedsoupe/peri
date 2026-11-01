# Data Generation

Generate sample data based on Peri schemas using StreamData. Add StreamData to
your dependencies to enable `Peri.generate/1`:

```elixir
# mix.exs
defp deps do
  [
    {:peri, "~> 0.12.0"}, # x-release-please-version
    {:stream_data, "~> 1.0", only: [:test, :dev]}
  ]
end
```

## Basic Usage

`Peri.generate/1` returns `{:ok, generator}` for a valid schema, or
`{:error, errors}` when schema validation fails. The returned StreamData
generator implements `Enumerable`:

```elixir
schema = %{
  name: {:required, :string},
  age: {:integer, gte: 18, lte: 120},
  active: :boolean
}

{:ok, generator} = Peri.generate(schema)
Enum.take(generator, 3)
```

Map fields are optional unless wrapped with `{:required, type}`. The generator
includes optional fields with generated values; required fields are also always
included.

## Supported Types

Generators are provided for all built-in scalar types:

| Type | Generated values |
| --- | --- |
| `:any` | Bounded StreamData terms |
| `:atom`, `:atom!` | Alphanumeric atoms |
| `:boolean` | Booleans |
| `:date` | Dates from 1970 through 2100 |
| `:datetime` | UTC datetimes from 1970 through 2100 |
| `:duration` | A finite one-second duration |
| `:float` | StreamData floats |
| `:integer` | StreamData integers |
| `:list` | Lists of at most five terms |
| `:map` | Empty maps |
| `:naive_datetime` | Naive datetimes from 1970 through 2100 |
| `:pid` | The current process PID |
| `:string` | Alphanumeric strings |
| `:time` | Times from midnight through 23:59:59 |

Composite schemas also support constrained lists, typed maps, tuples, enums,
literals, `:either`, `:oneof`, `:multi`, refs, defaults, coercions and custom
validators. Regex constraints and custom predicates use filtering, which can be
slow when only a small fraction of values match.

## Schema and Dependent Wrappers

`{:schema, type}`, `{:schema, type, opts}` and
`{:schema, map, {:additional_keys, value_type}}` generate from the wrapped
schema. Additional-key wrappers generate the declared fields only; random extra
keys are not necessary for a valid sample.

The fixed dependent form `{:dependent, field, condition, type}` generates values
from `type` and does not call `condition` during generation. Validation still
calls the condition with the real root data, so a dependent field should be
generated inside its parent map. Dynamic dependent forms such as
`{:dependent, callback}` select their schema at runtime and raise an
`ArgumentError` during generation; generation does not invoke that callback or
invent root data.

## Constraint-Aware Generation

Integer `gt`, `gte`, `lt`, `lte` and `range` constraints use bounded integer
generators. Combined bounds are intersected, including inclusive and exclusive
edges. Integer `multiple_of` constraints are combined with integer bounds when
the step is an integer. String `min` and `max` constraints set generator length
bounds; `eq` generates the exact value. Other constraints, including `neq`,
regex and custom predicates, are applied as filters where needed. Float ranges
and float `multiple_of` retain their existing generator behavior.

```elixir
schema = %{
  username: {:string, [min: 3, max: 12]},
  score: {:integer, [gt: 0, lte: 100]},
  role: {:enum, [:admin, :user, :guest]},
  tags: {:list, :string}
}

{:ok, generator} = Peri.generate(schema)
samples = Enum.take(generator, 5)
Enum.all?(samples, &(match?({:ok, _}, Peri.validate(schema, &1))))
```

## Property-Based Testing

Use the returned generator with ExUnitProperties:

```elixir
defmodule UserTest do
  use ExUnit.Case
  use ExUnitProperties

  @schema %{
    name: {:required, :string},
    age: {:integer, [gte: 0, lte: 120]},
    email: {:string, {:regex, ~r/@/}}
  }

  property "generated user data passes validation" do
    {:ok, generator} = Peri.generate(@schema)

    check all user_data <- generator do
      assert {:ok, _} = Peri.validate(@schema, user_data)
    end
  end
end
```

## Transforms

Generation preserves the existing one-argument transform behavior when the
transformed value is still valid input for the underlying schema. If the
callback raises for a generated value or returns a value that does not satisfy
the underlying schema, that sample remains the original valid input. MFA
transforms use their value-plus-arguments arity when available. Root-aware
two-argument function transforms, and MFA transforms that require a root value,
generate the underlying input without calling the callback. Validation then
applies the transform with the real root data; generation does not fabricate
root data.

## Recursive Refs

Ref generation is bounded to five expansions. At the depth limit, an optional
recursive ref is represented as `nil`, which validation treats as absent. A
schema whose recursive path is required at every level has no finite valid
value; generation raises an `ArgumentError` rather than yielding an invalid
sample. Add an optional base case to recursive schemas when finite sample
generation is needed.

## Custom Generators (`gen:`)

For supported `gen:` options, provide a function that returns a StreamData
generator. Accepted forms are `{module, function, args}`, `{module, function}`
for a zero-arity function, or a zero-arity function:

```elixir
defmodule MyApp.Gens do
  def adult_age, do: StreamData.integer(18..120)
  def fixed_login, do: StreamData.constant("system")
end

schema = %{
  age: {:integer, [gte: 18, lte: 120, gen: {MyApp.Gens, :adult_age, []}]},
  login: {:required, :string, [gen: {MyApp.Gens, :fixed_login}]}
}

{:ok, generator} = Peri.generate(schema)
Enum.take(generator, 5)
```

## Limitations

- Regex and custom predicates remain rejection-filtered and can be inefficient
  for narrow domains.
- Dynamic dependent schemas need a user-supplied generation strategy.
- Required-only recursion has no finite base value and is rejected during
  generation.
- Generation requires the optional StreamData dependency.

Use generation primarily for tests and development data, and keep generated
collection sizes reasonable.
