/// Test detail view showing full test case information.
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/ansi
import render/ccl_input
import render/entries
import render/error as render_error
import render/list as render_list
import render/object as render_object
import render/theme
import render/typed
import render/value as render_value
import shore
import shore/style
import shore/ui
import test_filter
import test_types.{
  type Expected, type TestCase, ExpectedBool, ExpectedBoolean, ExpectedCountOnly,
  ExpectedEntries, ExpectedError, ExpectedFloat, ExpectedInt, ExpectedList,
  ExpectedObject, ExpectedValue,
}
import tui/components
import tui/model.{type Model}
import tui/msg.{type Msg}
import util

/// Render the test detail view.
pub fn render(
  model: Model,
  file_path: String,
  test_index: Int,
) -> shore.Node(Msg) {
  let file_name = util.get_filename(file_path)

  case dict.get(model.loaded_suites, file_path) {
    Ok(suite) ->
      case list.drop(suite.tests, test_index) {
        [tc, ..] ->
          render_test_case(model, tc, test_index, list.length(suite.tests))
        [] -> render_not_found(file_name)
      }
    Error(_) -> render_loading(file_name)
  }
}

fn render_test_case(
  model: Model,
  tc: TestCase,
  index: Int,
  total: Int,
) -> shore.Node(Msg) {
  let is_compatible = test_filter.is_compatible(model.config, tc)
  let position = int.to_string(index + 1) <> "/" <> int.to_string(total)

  ui.col(
    list.flatten([
      [
        components.header(tc.name, position),
        ui.br(),
        // Metadata
        ui.text(
          ansi.fg("Validation: ", style.Cyan)
          <> tc.validation
          <> "   "
          <> ansi.fg("Compatible: ", style.Cyan)
          <> case is_compatible {
            True -> ansi.fg("Yes", style.Green)
            False -> ansi.fg("No", style.Red)
          },
        ),
        ui.br(),
        ui.text(
          ansi.fg("Functions: ", style.Cyan) <> string.join(tc.functions, ", "),
        ),
      ],
      // Optional metadata
      render_optional_tags("Behaviors", tc.behaviors),
      render_optional_tags("Features", tc.features),
      [
        ui.br(),
        ui.text_styled("INPUT (CCL)", Some(style.Yellow), None),
        ui.hr_styled(style.Blue),
        render_inputs(tc.inputs),
        ui.br(),
        ui.text_styled("EXPECTED", Some(style.Yellow), None),
        ui.hr_styled(style.Blue),
        render_expected(tc.expected),
      ],
      case tc.path {
        Some(path) -> [
          ui.text(ansi.fg("Path: ", style.Cyan) <> string.join(path, ".")),
        ]
        None -> []
      },
      [
        ui.br(),
        components.footer("[n/p] Next/Prev  [Esc] Back  [q] Quit"),
      ],
    ]),
  )
}

fn render_optional_tags(
  label: String,
  tags: List(String),
) -> List(shore.Node(Msg)) {
  case tags {
    [] -> []
    values -> [
      ui.text(ansi.fg(label <> ": ", style.Cyan) <> string.join(values, ", ")),
    ]
  }
}

fn render_inputs(inputs: List(String)) -> shore.Node(Msg) {
  let t = theme.default()
  case inputs {
    [] -> ui.text("(no input)")
    _ ->
      ui.text(
        inputs
        |> list.map(fn(input) { ccl_input.to_ansi(input, t) })
        |> string.join("\n"),
      )
  }
}

fn render_expected(expected: Expected) -> shore.Node(Msg) {
  let t = theme.default()
  let count_line = fn(count) {
    ansi.fg("count: ", style.Cyan) <> int.to_string(count)
  }

  case expected {
    ExpectedEntries(count, entry_list) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("entries:", style.Cyan)
        <> "\n"
        <> entries.to_ansi(entry_list, t),
      )

    ExpectedValue(count, value) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("value: ", style.Cyan)
        <> render_value.to_ansi(value, t),
      )

    ExpectedObject(count, object) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("object:", style.Cyan)
        <> "\n"
        <> render_object.to_ansi(object, t),
      )

    ExpectedList(count, items) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("list:", style.Cyan)
        <> "\n"
        <> render_list.to_ansi(items, t),
      )

    ExpectedInt(count, value) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("value: ", style.Cyan)
        <> typed.int_to_ansi(value, t),
      )

    ExpectedFloat(count, value) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("value: ", style.Cyan)
        <> typed.float_to_ansi(value, t),
      )

    ExpectedBool(count, value) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("value: ", style.Cyan)
        <> typed.bool_to_ansi(value, t),
      )

    ExpectedBoolean(count, boolean) ->
      ui.text(
        count_line(count)
        <> "\n"
        <> ansi.fg("boolean: ", style.Cyan)
        <> typed.bool_to_ansi(boolean, t),
      )

    ExpectedError(count, _error) ->
      ui.text(count_line(count) <> "\n" <> render_error.to_ansi())

    ExpectedCountOnly(count) -> ui.text(count_line(count))
  }
}

fn render_not_found(file_name: String) -> shore.Node(Msg) {
  ui.col([
    components.header(file_name, "Error"),
    ui.br(),
    ui.text_styled("Test not found", Some(style.Red), None),
  ])
}

fn render_loading(file_name: String) -> shore.Node(Msg) {
  ui.col([
    components.header(file_name, "Loading..."),
    ui.br(),
    ui.text("Loading test suite..."),
  ])
}
