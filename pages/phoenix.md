# Phoenix Integration

Validate params with a Peri schema and render Phoenix/LiveView forms without
Ecto. `Peri.Phoenix.to_form/3` decodes and validates params, wraps the result
in a `Peri.Form` struct, and converts it into a `Phoenix.HTML.Form` through
the `Phoenix.HTML.FormData` protocol, so `Phoenix.Component.form/1` and the
`<.input>` component work out of the box.

This integration is compiled only when the optional `phoenix_html` dependency
is present:

```elixir
# mix.exs
{:phoenix_html, "~> 4.1"}
```

## Basic Usage

```elixir
@schema %{
  name: {:required, :string},
  email: {:required, {:string, {:regex, ~r/@/}}},
  age: {:coerce, :string, {:integer, {:gte, 18}}}
}

# Valid params: the form carries the validated data and no errors
Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "email" => "jane@x.com", "age" => "27"})

# Invalid params: errors in changeset format, action set to :validate
form = Peri.Phoenix.to_form(@schema, %{"age" => "17"})
form.errors
# [name: {"is required, expected type of :string", []},
#  email: {"is required, expected type of :string", []},
#  age: {"should be greater then or equal to 18", []}]
```

Because params flow through `Peri.decode/3`, the `{:coerce, :string, target}`
directive converts string params into typed data: `"27"` validates as the
integer `27` and constraint failures like `"17"` against `{:gte, 18}` are
reported on the typed value.

## Options

`to_form/3` accepts the shared `Phoenix.HTML.FormData` options plus `:mode`:

- `:as` - form name, defaults to `"peri"`
- `:id` - form id, defaults to the name
- `:action` - form action (defaults to `:validate` when validation fails)
- `:mode` - validation mode forwarded to `Peri.decode/3` (`:strict` by
  default, `:permissive` keeps unknown fields)

## LiveView Round Trip

```elixir
defmodule MyAppWeb.SignupLive do
  use MyAppWeb, :live_view

  @schema %{
    name: {:required, :string},
    email: {:required, {:string, {:regex, ~r/@/}}},
    age: {:coerce, :string, {:integer, {:gte, 18}}}
  }

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: Peri.Phoenix.to_form(@schema))}
  end

  def handle_event("validate", %{"peri" => params}, socket) do
    {:noreply, assign(socket, form: Peri.Phoenix.to_form(@schema, params))}
  end

  def handle_event("save", %{"peri" => params}, socket) do
    case Peri.decode(@schema, params) do
      {:ok, data} ->
        # persist the typed data, redirect, ...
        {:noreply, socket}

      {:error, _errors} ->
        {:noreply, assign(socket, form: Peri.Phoenix.to_form(@schema, params))}
    end
  end

  def render(assigns) do
    ~H"""
    <.form for={@form} phx-change="validate" phx-submit="save">
      <.input field={@form[:name]} label="Name" />
      <.input field={@form[:email]} label="Email" />
      <.input field={@form[:age]} type="number" label="Age" />
      <button>Save</button>
    </.form>
    """
  end
end
```

The update path also accepts the form's source struct directly:
`Peri.Phoenix.to_form(form.source, new_params)` revalidates against the
stored schema.

HTML5 validations come from the schema: `{:required, type}` fields render
`required`, and `{:string, {:min, n}}` / `{:string, {:max, n}}` render
`minlength` / `maxlength`.

## Nested Schemas and `inputs_for`

Nested map schemas work with `Phoenix.HTML.FormData.to_form/4` (what
`inputs_for` calls under the hood), and nested errors surface in the nested
form:

```elixir
@schema %{
  name: {:required, :string},
  address: %{
    street: {:required, :string},
    city: :string
  }
}

form = Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "address" => %{}})
[address_form] = Phoenix.HTML.FormData.to_form(form.source, form, :address, [])
address_form[:street].errors
# [{"is required, expected type of :string", []}]
```

List-of-map schemas (`{:list, %{...}}`) expand to one form per entry, keyed
by index (`peri[tags][0]`, `peri[tags][1]`, ...), reading values from params
first and falling back to validated data.

## Caveats

- **No changeset parity.** `Peri.Form` carries validated data, raw params,
  and errors; it does not track changes, touch state, or apply/rollback
  semantics. If you need those, use the Ecto integration instead.
- **List element errors are not indexed.** Peri currently reports errors
  inside list elements at the field level (e.g. `[:tags, :label]`) rather
  than per index (`[:tags, 0, :label]`), so per-entry errors for
  list-of-map schemas cannot be attributed to a specific form entry. Nested
  map errors are fully supported.
- **Failed validation discards data.** When validation fails the form keeps
  only the raw params (which is what inputs re-render from), not a partially
  validated result.
