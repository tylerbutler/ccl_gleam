/// Test list view for browsing tests within a file.
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import shore
import shore/style
import shore/ui
import test_filter
import test_types.{type TestCase}
import tui/components
import tui/model.{type Model}
import tui/msg.{type Msg}
import util

/// Render the test list view.
pub fn render(model: Model, file_path: String) -> shore.Node(Msg) {
  let file_name = util.get_filename(file_path)

  case dict.get(model.loaded_suites, file_path) {
    Ok(suite) -> {
      let tests = suite.tests
      let total = list.length(tests)
      let #(start, end) = model.visible_bounds(model, total)

      ui.col([
        components.header(file_name, int.to_string(total) <> " tests"),
        ui.br(),
        ui.col(
          tests
          |> list.index_map(fn(tc, idx) { #(tc, idx) })
          |> list.filter(fn(pair) { pair.1 >= start && pair.1 < end })
          |> list.map(fn(pair) {
            let #(tc, idx) = pair
            render_test_row(
              tc,
              idx == model.selected_index,
              test_filter.is_compatible(model.config, tc),
            )
          }),
        ),
        components.scroll_indicator(model, total),
        ui.br(),
        components.footer("[j/k] Navigate  [Enter] View  [Esc] Back  [q] Quit"),
      ])
    }
    Error(_) ->
      ui.col([
        components.header(file_name, "Loading..."),
        ui.br(),
        ui.text("Loading test suite..."),
      ])
  }
}

fn render_test_row(
  tc: TestCase,
  is_selected: Bool,
  is_compatible: Bool,
) -> shore.Node(Msg) {
  let marker = components.selection_marker(is_selected)
  let name = util.truncate(tc.name, 45)
  let tags = format_tags(tc)

  let line = marker <> util.pad_right(name, 47) <> " " <> tags

  case is_selected, is_compatible {
    True, True -> ui.text_styled(line, Some(style.Black), Some(style.Cyan))
    True, False -> ui.text_styled(line, Some(style.Black), Some(style.Yellow))
    False, True -> ui.text(line)
    False, False -> ui.text_styled(line, Some(style.Yellow), None)
  }
}

fn format_tags(tc: TestCase) -> String {
  let tags =
    tc.functions
    |> list.take(3)
    |> list.map(fn(f) { "[" <> f <> "]" })
    |> string.join(" ")

  case list.length(tc.functions) > 3 {
    True -> tags <> " ..."
    False -> tags
  }
}
