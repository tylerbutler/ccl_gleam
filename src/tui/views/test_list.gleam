/// Test list view for browsing tests within a file
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
import test_runner/types.{type TestCase}
import tui/components
import tui/model.{type Model}
import tui/msg.{type Msg}

/// Render the test list view
pub fn render(model: Model, file_path: String) -> shore.Node(Msg) {
  let file_name = get_filename(file_path)

  case dict.get(model.loaded_suites, file_path) {
    Ok(suite) -> {
      let tests = suite.tests
      let total = list.length(tests)
      let #(start, end) = model.visible_bounds(model, total)

      ui.col([
        // Header
        components.header(file_name, int.to_string(total) <> " tests"),
        ui.br(),
        // Test list
        ui.col(
          tests
          |> list.index_map(fn(tc, idx) { #(tc, idx) })
          |> list.filter(fn(pair) { pair.1 >= start && pair.1 < end })
          |> list.map(fn(pair) {
            let #(tc, idx) = pair
            let is_selected = idx == model.selected_index
            let is_compatible = filter.is_compatible(model.config, tc)
            render_test_row(tc, is_selected, is_compatible)
          }),
        ),
        // Scroll indicator
        render_scroll_indicator(model, total),
        ui.br(),
        // Footer
        components.footer("[j/k] Navigate  [Enter] View  [Esc] Back  [q] Quit"),
      ])
    }
    Error(_) -> {
      ui.col([
        components.header(file_name, "Loading..."),
        ui.br(),
        ui.text("Loading test suite..."),
      ])
    }
  }
}

/// Render a single test row
fn render_test_row(
  tc: TestCase,
  is_selected: Bool,
  is_compatible: Bool,
) -> shore.Node(Msg) {
  let marker = components.selection_marker(is_selected)
  let name = truncate(tc.name, 45)
  let tags = format_tags(tc)

  let line = marker <> pad_right(name, 47) <> " " <> tags

  case is_selected, is_compatible {
    True, True -> ui.text_styled(line, Some(style.Black), Some(style.Cyan))
    True, False -> ui.text_styled(line, Some(style.Black), Some(style.Yellow))
    False, True -> ui.text(line)
    False, False -> ui.text_styled(line, Some(style.Yellow), None)
  }
}

/// Format tags for display
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

/// Render scroll indicator
fn render_scroll_indicator(model: Model, total: Int) -> shore.Node(Msg) {
  let visible = model.terminal_height - 5
  case total > visible {
    True -> {
      let position = model.selected_index + 1
      let indicator =
        " (" <> int.to_string(position) <> "/" <> int.to_string(total) <> ")"
      ui.text_styled(indicator, Some(style.Yellow), None)
    }
    False -> ui.text("")
  }
}

// Helper functions

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn pad_right(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> s <> string.repeat(" ", width - len)
  }
}

fn truncate(s: String, max_len: Int) -> String {
  case string.length(s) > max_len {
    True -> string.slice(s, 0, max_len - 3) <> "..."
    False -> s
  }
}
