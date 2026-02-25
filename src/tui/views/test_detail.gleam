/// Test detail view showing full test case information
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import shore
import shore/style
import shore/ui
import test_runner/filter
import test_runner/types.{
  type Expected, type ExpectedNode, type TestCase, ExpectedBool, ExpectedBoolean,
  ExpectedCountOnly, ExpectedEntries, ExpectedError, ExpectedFloat, ExpectedInt,
  ExpectedList, ExpectedObject, ExpectedValue, NodeList, NodeObject, NodeString,
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
  let is_compatible = filter.is_compatible(model.config, tc)
  let position = int.to_string(index + 1) <> "/" <> int.to_string(total)

  ui.col([
    // Header
    components.header(tc.name, position),
    ui.br(),
    // Metadata section
    ui.row([
      ui.text_styled("Validation: ", Some(style.Cyan), None),
      ui.text(tc.validation),
      ui.text("   "),
      ui.text_styled("Compatible: ", Some(style.Cyan), None),
      case is_compatible {
        True -> ui.text_styled("Yes", Some(style.Green), None)
        False -> ui.text_styled("No", Some(style.Red), None)
      },
    ]),
    ui.br(),
    // Functions
    ui.row([
      ui.text_styled("Functions: ", Some(style.Cyan), None),
      ui.text(string.join(tc.functions, ", ")),
    ]),
    // Behaviors (if any)
    case tc.behaviors {
      [] -> ui.text("")
      behaviors ->
        ui.row([
          ui.text_styled("Behaviors: ", Some(style.Cyan), None),
          ui.text(string.join(behaviors, ", ")),
        ])
    },
    // Features (if any)
    case tc.features {
      [] -> ui.text("")
      features ->
        ui.row([
          ui.text_styled("Features: ", Some(style.Cyan), None),
          ui.text(string.join(features, ", ")),
        ])
    },
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
    // Path (if any)
    case tc.path {
      Some(path) ->
        ui.row([
          ui.text_styled("Path: ", Some(style.Cyan), None),
          ui.text(string.join(path, ".")),
        ])
      None -> ui.text("")
    },
    ui.br(),
    // Footer
    components.footer("[n/p] Next/Prev  [Esc] Back  [q] Quit"),
  ])
}

fn render_inputs(inputs: List(String)) -> shore.Node(Msg) {
  case inputs {
    [] -> ui.text("(no input)")
    _ ->
      ui.col(
        inputs
        |> list.map(fn(input) { ui.text(format_input(input)) }),
      )
  }
}

fn format_input(input: String) -> String {
  // Show escape sequences visually
  input
  |> string.replace("\n", "\\n\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

fn render_expected(expected: Expected) -> shore.Node(Msg) {
  case expected {
    ExpectedEntries(count, entries) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.text_styled("entries:", Some(style.Cyan), None),
        ui.col(
          entries
          |> list.map(fn(e) { ui.text("  " <> e.key <> " = " <> e.value) }),
        ),
      ])

    ExpectedValue(count, value) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.row([
          ui.text_styled("value: ", Some(style.Cyan), None),
          ui.text("\"" <> value <> "\""),
        ]),
      ])

    ExpectedObject(count, object) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.text_styled("object:", Some(style.Cyan), None),
        render_object(object, 1),
      ])

    ExpectedList(count, items) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.row([
          ui.text_styled("list: ", Some(style.Cyan), None),
          ui.text("[" <> string.join(items, ", ") <> "]"),
        ]),
      ])

    ExpectedInt(count, value) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.row([
          ui.text_styled("value: ", Some(style.Cyan), None),
          ui.text(int.to_string(value)),
        ]),
      ])

    ExpectedFloat(count, value) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.row([
          ui.text_styled("value: ", Some(style.Cyan), None),
          ui.text(float_to_string(value)),
        ]),
      ])

    ExpectedBool(count, value) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.row([
          ui.text_styled("value: ", Some(style.Cyan), None),
          ui.text(bool_to_string(value)),
        ]),
      ])

    ExpectedBoolean(count, boolean) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.row([
          ui.text_styled("boolean: ", Some(style.Cyan), None),
          ui.text(bool_to_string(boolean)),
        ]),
      ])

    ExpectedError(count, _error) ->
      ui.col([
        ui.row([
          ui.text_styled("count: ", Some(style.Cyan), None),
          ui.text(int.to_string(count)),
        ]),
        ui.text_styled("error: ", Some(style.Red), None),
        ui.text("true"),
      ])

    ExpectedCountOnly(count) ->
      ui.row([
        ui.text_styled("count: ", Some(style.Cyan), None),
        ui.text(int.to_string(count)),
      ])
  }
}

fn render_object(
  object: dict.Dict(String, ExpectedNode),
  indent: Int,
) -> shore.Node(Msg) {
  let prefix = string.repeat("  ", indent)
  ui.col(
    object
    |> dict.to_list
    |> list.map(fn(pair) {
      let #(key, value) = pair
      case value {
        NodeString(s) -> ui.text(prefix <> key <> ": \"" <> s <> "\"")
        NodeList(items) ->
          ui.text(prefix <> key <> ": [" <> string.join(items, ", ") <> "]")
        NodeObject(nested) ->
          ui.col([
            ui.text(prefix <> key <> ":"),
            render_object(nested, indent + 1),
          ])
      }
    }),
  )
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

// Helper functions

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

fn float_to_string(f: Float) -> String {
  // Use Erlang's float_to_list for proper formatting
  erlang_float_to_string(f)
}

@external(erlang, "erlang", "float_to_list")
fn erlang_float_to_list(f: Float) -> List(Int)

fn erlang_float_to_string(f: Float) -> String {
  f
  |> erlang_float_to_list
  |> list.map(fn(c) { string.utf_codepoint(c) })
  |> list.filter_map(fn(r) {
    case r {
      Ok(cp) -> Ok(cp)
      Error(_) -> Error(Nil)
    }
  })
  |> string.from_utf_codepoints
}
