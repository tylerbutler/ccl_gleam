/// Test detail view showing full test case information
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
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

/// Render the test detail view
pub fn render(
  model: Model,
  file_path: String,
  test_index: Int,
) -> shore.Node(Msg) {
  let file_name = get_filename(file_path)

  case dict.get(model.loaded_suites, file_path) {
    Ok(suite) -> {
      case list.drop(suite.tests, test_index) {
        [tc, ..] ->
          render_test_case(
            model,
            file_name,
            tc,
            test_index,
            list.length(suite.tests),
          )
        [] -> render_not_found(file_name)
      }
    }
    Error(_) -> render_loading(file_name)
  }
}

fn render_test_case(
  model: Model,
  _file_name: String,
  tc: TestCase,
  index: Int,
  total: Int,
) -> shore.Node(Msg) {
  let is_compatible = test_filter.is_compatible(model.config, tc)
  let position = int.to_string(index + 1) <> "/" <> int.to_string(total)

  ui.col(list.flatten([
    [
      // Header
      components.header(tc.name, position),
      ui.br(),
      // Metadata section
      ui.text(
        ansi_fg(style.Cyan)
        <> "Validation: "
        <> ansi_reset()
        <> tc.validation
        <> "   "
        <> ansi_fg(style.Cyan)
        <> "Compatible: "
        <> ansi_reset()
        <> case is_compatible {
          True -> ansi_fg(style.Green) <> "Yes" <> ansi_reset()
          False -> ansi_fg(style.Red) <> "No" <> ansi_reset()
        },
      ),
      ui.br(),
      // Functions
      ui.text(
        ansi_fg(style.Cyan)
        <> "Functions: "
        <> ansi_reset()
        <> string.join(tc.functions, ", "),
      ),
    ],
    // Behaviors (if any)
    case tc.behaviors {
      [] -> []
      behaviors -> [
        ui.text(
          ansi_fg(style.Cyan)
          <> "Behaviors: "
          <> ansi_reset()
          <> string.join(behaviors, ", "),
        ),
      ]
    },
    // Features (if any)
    case tc.features {
      [] -> []
      features -> [
        ui.text(
          ansi_fg(style.Cyan)
          <> "Features: "
          <> ansi_reset()
          <> string.join(features, ", "),
        ),
      ]
    },
    [
      ui.br(),
      // Input section
      ui.text_styled("INPUT (CCL)", Some(style.Yellow), None),
      ui.hr_styled(style.Blue),
      render_inputs(tc.inputs),
      ui.br(),
      // Expected section
      ui.text_styled("EXPECTED", Some(style.Yellow), None),
      ui.hr_styled(style.Blue),
      render_expected(tc.expected),
    ],
    // Path (if any)
    case tc.path {
      Some(path) -> [
        ui.text(
          ansi_fg(style.Cyan)
          <> "Path: "
          <> ansi_reset()
          <> string.join(path, "."),
        ),
      ]
      None -> []
    },
    [
      ui.br(),
      // Footer
      components.footer("[n/p] Next/Prev  [Esc] Back  [q] Quit"),
    ],
  ]))
}

fn render_inputs(inputs: List(String)) -> shore.Node(Msg) {
  let default_theme = theme.default()
  case inputs {
    [] -> ui.text("(no input)")
    _ ->
      ui.text(
        inputs
        |> list.map(fn(input) { ccl_input.to_ansi(input, default_theme) })
        |> string.join("\n"),
      )
  }
}

fn render_expected(expected: Expected) -> shore.Node(Msg) {
  let default_theme = theme.default()
  case expected {
    ExpectedEntries(count, entry_list) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "entries:"
        <> ansi_reset()
        <> "\n"
        <> entries.to_ansi(entry_list, default_theme),
      )

    ExpectedValue(count, value) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "value: "
        <> ansi_reset()
        <> render_value.to_ansi(value, default_theme),
      )

    ExpectedObject(count, object) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "object:"
        <> ansi_reset()
        <> "\n"
        <> render_object.to_ansi(object, default_theme),
      )

    ExpectedList(count, items) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "list:"
        <> ansi_reset()
        <> "\n"
        <> render_list.to_ansi(items, default_theme),
      )

    ExpectedInt(count, value) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "value: "
        <> ansi_reset()
        <> typed.int_to_ansi(value, default_theme),
      )

    ExpectedFloat(count, value) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "value: "
        <> ansi_reset()
        <> typed.float_to_ansi(value, default_theme),
      )

    ExpectedBool(count, value) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "value: "
        <> ansi_reset()
        <> typed.bool_to_ansi(value, default_theme),
      )

    ExpectedBoolean(count, boolean) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> ansi_fg(style.Cyan)
        <> "boolean: "
        <> ansi_reset()
        <> typed.bool_to_ansi(boolean, default_theme),
      )

    ExpectedError(count, _error) ->
      ui.text(
        ansi_fg(style.Cyan)
        <> "count: "
        <> ansi_reset()
        <> int.to_string(count)
        <> "\n"
        <> render_error.to_ansi(),
      )

    ExpectedCountOnly(count) ->
      ui.text(
        ansi_fg(style.Cyan) <> "count: " <> ansi_reset() <> int.to_string(count),
      )
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

// ANSI color helpers

fn ansi_fg(color: style.Color) -> String {
  let code = case color {
    style.Black -> "30"
    style.Red -> "31"
    style.Green -> "32"
    style.Yellow -> "33"
    style.Blue -> "34"
    style.Magenta -> "35"
    style.Cyan -> "36"
    style.White -> "37"
  }
  "\u{001b}[" <> code <> "m"
}

fn ansi_reset() -> String {
  "\u{001b}[0m"
}

// Helper functions

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}
