defmodule Peri.PhoenixTest do
  use ExUnit.Case, async: true

  alias Phoenix.HTML.FormData

  @schema %{
    name: {:required, :string},
    email: {:required, {:string, {:regex, ~r/@/}}},
    age: {:coerce, :string, {:integer, {:gte, 18}}}
  }

  @nested_schema %{
    name: {:required, :string},
    address: %{
      street: {:required, :string},
      city: :string
    },
    tags: {:list, %{label: {:required, :string}}}
  }

  describe "to_form/3 with valid params" do
    test "returns a form with no errors and validated data" do
      form =
        Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "email" => "jane@x.com", "age" => "27"})

      assert %Phoenix.HTML.Form{} = form
      assert form.errors == []
      assert form.action == nil
      assert form.source.data == %{name: "Jane", email: "jane@x.com", age: 27}
    end

    test "field values are accessible through Phoenix.HTML.Form functions" do
      form =
        Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "email" => "jane@x.com", "age" => "27"})

      assert Phoenix.HTML.Form.input_value(form, :name) == "Jane"
      assert Phoenix.HTML.Form.input_id(form, :name) == "peri_name"
      assert Phoenix.HTML.Form.input_name(form, :name) == "peri[name]"
    end

    test "respects the :as option for the form name" do
      form = Peri.Phoenix.to_form(@schema, %{"name" => "Jane"}, as: :user)

      assert form.name == "user"
      assert Phoenix.HTML.Form.input_name(form, :name) == "user[name]"
    end
  end

  describe "to_form/3 with invalid params" do
    test "errors are stored in changeset format" do
      form = Peri.Phoenix.to_form(@schema, %{"age" => "17"})

      assert %Peri.Form{errors: errors} = form.source

      assert %{name: [{"is required, expected type of :string", []}], email: [{_, []}]} = errors
    end

    test "flat form errors and FormField access expose messages" do
      form =
        Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "email" => "jane@x.com", "age" => "17"})

      assert [age: {"should be greater then or equal to 18", []}] = form.errors
      assert form.action == :validate

      assert %Phoenix.HTML.FormField{errors: [{"should be greater then or equal to 18", []}]} =
               form[:age]
    end

    test "keeps raw params as field values for re-rendering" do
      form = Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "age" => "17"})

      assert Phoenix.HTML.Form.input_value(form, :name) == "Jane"
      assert Phoenix.HTML.Form.input_value(form, :age) == "17"
    end
  end

  describe "coercion" do
    test "string params are coerced by the schema and rendered from params" do
      form =
        Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "email" => "j@x.com", "age" => "30"})

      assert form.source.data.age == 30
      assert Phoenix.HTML.Form.input_value(form, :age) == "30"
    end
  end

  describe "nested forms (inputs_for)" do
    test "nested map errors surface in the nested form" do
      form = Peri.Phoenix.to_form(@nested_schema, %{"name" => "Jane", "address" => %{}})

      assert [address] = FormData.to_form(form.source, form, :address, [])
      assert address.id == "peri_address"
      assert address.name == "peri[address]"
      assert [street: {"is required, expected type of :string", []}] = address.errors

      assert %Phoenix.HTML.FormField{
               name: "peri[address][street]",
               errors: [{"is required, expected type of :string", []}]
             } = address[:street]
    end

    test "valid nested maps carry their values" do
      params = %{"name" => "Jane", "address" => %{"street" => "Main St", "city" => "Recife"}}
      form = Peri.Phoenix.to_form(@nested_schema, params)

      assert [address] = FormData.to_form(form.source, form, :address, [])
      assert address.errors == []
      assert Phoenix.HTML.Form.input_value(address, :street) == "Main St"
      assert Phoenix.HTML.Form.input_value(address, :city) == "Recife"
    end

    test "list of maps expands to one form per entry" do
      params = %{"name" => "Jane", "tags" => [%{"label" => "a"}, %{"label" => "b"}]}
      form = Peri.Phoenix.to_form(@nested_schema, params)

      assert [first, second] = FormData.to_form(form.source, form, :tags, [])

      assert {first.index, first.id, first.name} == {0, "peri_tags_0", "peri[tags][0]"}
      assert {second.index, second.id, second.name} == {1, "peri_tags_1", "peri[tags][1]"}
      assert Phoenix.HTML.Form.input_value(first, :label) == "a"
      assert Phoenix.HTML.Form.input_value(second, :label) == "b"
    end

    test "list of maps renders from validated data when no params are present" do
      form =
        Peri.Phoenix.to_form(@nested_schema, %{"name" => "Jane", "tags" => [%{"label" => "a"}]})

      source = %{form.source | params: %{}}
      form = FormData.to_form(source, [])

      assert [first] = FormData.to_form(source, form, :tags, [])
      assert Phoenix.HTML.Form.input_value(first, :label) == "a"
    end
  end

  describe "form update path" do
    test "accepts a Peri.Form and revalidates new params against its schema" do
      form =
        Peri.Phoenix.to_form(@schema, %{"name" => "Jane", "email" => "j@x.com", "age" => "30"})

      updated =
        Peri.Phoenix.to_form(form.source, %{"name" => "June", "email" => "j@x.com", "age" => "31"})

      assert Phoenix.HTML.Form.input_value(updated, :name) == "June"
      assert updated.source.data.age == 31
    end

    test "converts a Peri.Form as is when no new params are given" do
      peri_form = %Peri.Form{schema: @schema, data: %{name: "Jane"}, params: %{}}

      form = Peri.Phoenix.to_form(peri_form)

      assert %Phoenix.HTML.Form{} = form
      assert Phoenix.HTML.Form.input_value(form, :name) == "Jane"
    end
  end

  describe "input_validations/2" do
    test "required fields are flagged and string constraints map to HTML validations" do
      schema = %{name: {:required, {:string, {:min, 2}}}, bio: {:string, {:max, 10}}}
      form = Peri.Phoenix.to_form(schema, %{})

      assert Phoenix.HTML.Form.input_validations(form, :name) == [required: true, minlength: 2]
      assert Phoenix.HTML.Form.input_validations(form, :bio) == [maxlength: 10]
    end

    test "optional fields without constraints have no validations" do
      form = Peri.Phoenix.to_form(@schema, %{})

      assert Phoenix.HTML.Form.input_validations(form, :age) == []
    end
  end
end
