defmodule EpicenterWeb.Form do
  use Phoenix.HTML

  import EpicenterWeb.ErrorHelpers
  import EpicenterWeb.FormHelpers

  alias EpicenterWeb.FormHelpers

  alias EpicenterWeb.Form

  defstruct ~w{f safe}a

  defmodule Line do
    defstruct ~w{column f safe}a
  end

  def new(f),
    do: %Form{f: f, safe: []}

  def safe(%Form{safe: safe}),
    do: {:safe, safe}

  def line(%Form{} = form, fun) do
    line = %Line{column: 1, f: form.f, safe: []} |> fun.()
    %{form | safe: merge_safe(form.safe, content_tag(:fieldset, line.safe))}
  end

  # # #

  @doc "opts: span"
  def checkbox_list_field(%Form.Line{f: f} = line, field, name, values, opts \\ []) do
    [
      label(f, field, name, data: grid_data(1, line, opts)),
      error_tag(f, field, data: grid_data(2, line, opts)),
      checkbox_list(f, field, values, data: grid_data(3, line, opts))
    ]
    |> add_to_line(line, opts)
  end

  @doc "opts: span"
  def content_div(%Form.Line{} = line, content, opts \\ []) do
    [
      content_tag(:div, content, data: grid_data(1, line, opts))
    ]
    |> add_to_line(line, opts)
  end

  @doc "opts: span"
  def date_field(%Form.Line{f: f} = line, field, name, opts \\ []) do
    [
      label(f, field, name, data: grid_data(1, line, opts)),
      content_tag(:div, "MM/DD/YYYY", data: grid_data(2, line, opts)),
      error_tag(f, field, data: grid_data(3, line, opts)),
      text_input(f, field, data: grid_data(4, line, opts))
    ]
    |> add_to_line(line, opts)
  end

  @doc "opts: span"
  def footer(%Form.Line{} = line, error_message, opts \\ []) do
    content_tag :footer do
      [
        submit("Save"),
        content_tag(:div, error_message, class: "form-error-message", "data-form-error-message": error_message)
      ]
    end
    |> add_to_line(line, opts)
  end

  @doc "opts: other, span"
  def radio_button_list(%Form.Line{f: f} = line, field, name, values, opts \\ []) do
    [
      label(f, field, name, data: grid_data(1, line, opts)),
      error_tag(f, field, data: grid_data(2, line, opts)),
      FormHelpers.radio_button_list(f, field, values, opts, data: grid_data(3, line, opts))
    ]
    |> add_to_line(line, opts)
  end

  @doc "opts: span"
  def save_button(%Form.Line{} = line, opts \\ []) do
    submit("Save", data: grid_data(1, line, opts))
    |> add_to_line(line, opts)
  end

  @doc "opts: span"
  def select(%Form.Line{f: f} = line, field, name, options, opts \\ []) do
    [
      label(f, field, name, data: grid_data(1, line, opts)),
      error_tag(f, field, data: grid_data(2, line, opts)),
      FormHelpers.select_with_wrapper(f, field, options, data: grid_data(3, line, opts))
    ]
    |> add_to_line(line, opts)
  end

  @doc "opts: span"
  def text_field(%Form.Line{f: f} = line, field, name, opts \\ []) do
    [
      label(f, field, name, data: grid_data(1, line, opts)),
      error_tag(f, field, data: grid_data(2, line, opts)),
      text_input(f, field, data: grid_data(3, line, opts))
    ]
    |> add_to_line(line, opts)
  end

  # # #

  defp grid_data(row, %Form.Line{column: column}, opts),
    do: [grid: [row: row, col: column, span: Keyword.get(opts, :span, 2)]]

  defp add_to_line(contents, %Form.Line{column: column, safe: safe} = line, opts),
    do: %{line | column: column + Keyword.get(opts, :span, 2), safe: safe ++ contents}

  defp merge_safe({:safe, left}, {:safe, right}), do: left ++ right
  defp merge_safe(left, {:safe, right}), do: left ++ right
  defp merge_safe({:safe, left}, right), do: left ++ right
end
