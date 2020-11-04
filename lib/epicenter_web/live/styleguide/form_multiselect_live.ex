defmodule EpicenterWeb.Styleguide.FormMultiselectLive do
  use EpicenterWeb, :live_view

  import EpicenterWeb.LiveHelpers, only: [assign_page_title: 2, noreply: 1, ok: 1]

  alias EpicenterWeb.Form

  # fake schema (would be a database-backed schema in real code)
  defmodule Example do
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false

    embedded_schema do
      field :radios, :string
      field :checkboxes, {:array, :string}
      field :radios_and_checkboxes, {:array, :string}
      field :radios_with_nested_checkboxes, {:array, :string}
      field :radios_and_checkboxes_with_nested_checkboxes, {:array, :string}
    end

    @required_attrs ~w{
      radios
      checkboxes
      radios_and_checkboxes
      radios_with_nested_checkboxes
      radios_and_checkboxes_with_nested_checkboxes
    }a
    @optional_attrs ~w{}a

    def changeset(example, attrs) do
      example
      |> cast(attrs, @required_attrs ++ @optional_attrs)
      |> validate_required(@required_attrs)
    end
  end

  # fake context
  defmodule Examples do
    import Ecto.Changeset

    @doc "simulate inserting into the db"
    def create_example(attrs) do
      %Example{} |> Example.changeset(attrs) |> apply_action(:create)
    end

    @doc "simulate getting a example from the db"
    def get_example() do
      %Example{
        radios: "r2",
        checkboxes: ["c1", "c3"],
        radios_and_checkboxes: ["c1", "c3"],
        radios_with_nested_checkboxes: ["r2", "c1", "c2"],
        radios_and_checkboxes_with_nested_checkboxes: ["c1", "c1.1", "c1.3", "c2", "c2.1"]
      }
    end
  end

  defmodule ExampleForm do
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false

    embedded_schema do
      field :radios, {:array, :string}
      field :checkboxes, {:array, :string}
      field :radios_and_checkboxes, {:array, :string}
      field :radios_with_nested_checkboxes, {:array, :string}
      field :radios_and_checkboxes_with_nested_checkboxes, {:array, :string}
    end

    @required_attrs ~w{
      radios
      checkboxes
      radios_and_checkboxes
      radios_with_nested_checkboxes
      radios_and_checkboxes_with_nested_checkboxes
    }a
    @optional_attrs ~w{}a

    def changeset(%Example{} = example) do
      example
      |> example_form_attrs()
      |> convert(:radios, :string_to_list)
      |> changeset()
    end

    def changeset(form_attrs) do
      %ExampleForm{}
      |> cast(form_attrs, @required_attrs ++ @optional_attrs)
      |> validate_required(@required_attrs)
    end

    def example_attrs(%Ecto.Changeset{} = changeset) do
      case apply_action(changeset, :create) do
        {:ok, example_form} -> {:ok, example_attrs(example_form)}
        other -> other
      end
    end

    def example_attrs(%ExampleForm{} = example_form) do
      example_form
      |> Map.from_struct()
      |> convert(:radios, :list_to_string)
    end

    def example_form_attrs(%Example{} = example) do
      example
      |> Map.from_struct()
    end

    defp convert(%{radios: [radio]} = attrs, :radios, :list_to_string),
      do: Map.put(attrs, :radios, radio)

    defp convert(%{radios: radio} = attrs, :radios, :string_to_list),
      do: Map.put(attrs, :radios, [radio])
  end

  def mount(_params, _session, socket) do
    example = Examples.get_example()

    socket
    |> assign_page_title("Styleguide: multiselect")
    |> assign(show_nav: false)
    |> assign_form_changeset(ExampleForm.changeset(example))
    |> assign_example(nil)
    |> ok()
  end

  def handle_event("save", %{"example_form" => params}, socket) do
    with %Ecto.Changeset{} = form_changeset <- ExampleForm.changeset(params),
         {:example_form, {:ok, example_attrs}} <- {:example_form, ExampleForm.example_attrs(form_changeset)},
         {:example, {:ok, example}} <- {:example, Examples.create_example(example_attrs)} do
      IO.inspect(example, label: "example")
      socket |> assign_form_changeset(form_changeset) |> assign_example(example) |> noreply()
    else
      {:example_form, {:error, %Ecto.Changeset{valid?: false} = form_changeset}} ->
        socket |> assign_form_changeset(form_changeset) |> noreply()

      {:example, {:error, _} = error} ->
        IO.inspect(error, label: "error")
        socket |> assign_form_changeset(ExampleForm.changeset(params), "An unexpected error occurred") |> noreply()
    end
  end

  def example_form_builder(form, form_error) do
    Form.new(form)
    |> Form.line(fn line ->
      line
      |> Form.wip_multiselect(
        :radios,
        "Radios",
        [{:radio, "R1", "r1"}, {:radio, "R2", "r2"}, {:radio, "R3", "r3"}, {:radio, "R4", "r4"}],
        span: 2
      )
      |> Form.wip_multiselect(
        :checkboxes,
        "Checkboxes",
        [{:checkbox, "C1", "c1"}, {:checkbox, "C2", "c2"}, {:checkbox, "C3", "c3"}, {:checkbox, "C4", "c4"}],
        span: 2
      )
      |> Form.wip_multiselect(
        :radios_and_checkboxes,
        "Mixed",
        [{:radio, "R1", "r1"}, {:radio, "R2", "r2"}, {:checkbox, "C1", "c1"}, {:checkbox, "C2", "c2"}],
        span: 2
      )
    end)
    |> Form.line(fn line ->
      line
      |> Form.wip_multiselect(
        :radios_with_nested_checkboxes,
        "Radios + nested checkboxes",
        [
          {:radio, "R1", "r1"},
          {:radio, "R2", "r2", [{:checkbox, "C1", "c1"}, {:checkbox, "C2", "c2"}]},
          {:radio, "R3", "r3", [{:checkbox, "C3", "c3"}, {:checkbox, "C4", "c4"}]}
        ],
        span: 3
      )
      |> Form.wip_multiselect(
        :radios_and_checkboxes_with_nested_checkboxes,
        "Mixed + nested checkboxes",
        [
          {:radio, "R1", "r1"},
          {:radio, "R2", "r2"},
          {:checkbox, "C1", "c1", [{:checkbox, "C1.1", "c1.1"}, {:checkbox, "C1.2", "c1.2"}, {:checkbox, "C1.3", "c1.3"}]},
          {:checkbox, "C2", "c2", [{:checkbox, "C2.1", "c2.1"}, {:checkbox, "C2.2", "c2.2"}]}
        ],
        span: 3
      )
    end)
    |> Form.line(&Form.footer(&1, form_error, sticky: false))
    |> Form.safe()
  end

  # # #

  defp assign_example(socket, example),
    do: socket |> assign(example: example, form_error: nil)

  defp assign_form_changeset(socket, %Ecto.Changeset{valid?: false} = changeset),
    do: socket |> assign_form_changeset(changeset, "Check the errors above")

  defp assign_form_changeset(socket, %Ecto.Changeset{} = changeset, form_error \\ nil),
    do: socket |> assign(form_changeset: changeset, form_error: form_error)
end