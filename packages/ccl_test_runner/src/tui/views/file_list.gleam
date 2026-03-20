/// File list view for browsing test files
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import shore
import shore/style
import shore/ui
import tui/components
import tui/model.{type Model}
import tui/msg.{type Msg}

/// Render the file list view
pub fn render(model: Model) -> shore.Node(Msg) {
  let #(start, end) = model.visible_bounds(model, list.length(model.files))

  ui.col([
    // Header
    components.header("Files", "Directory: " <> model.test_dir),
    ui.br(),
    // Column headers
    ui.row([
      ui.text_styled(
        "  "
          <> pad_right("FILE", 42)
          <> " "
          <> pad_left("TESTS", 6)
          <> "  "
          <> pad_left("SIZE", 6),
        Some(style.Cyan),
        None,
      ),
    ]),
    ui.hr_styled(style.Blue),
    // File list
    ui.col(
      model.files
      |> list.index_map(fn(file, idx) { #(file, idx) })
      |> list.filter(fn(pair) { pair.1 >= start && pair.1 < end })
      |> list.map(fn(pair) {
        let #(file, idx) = pair
        let is_selected = idx == model.selected_index
        render_file_row(file, is_selected)
      }),
    ),
    // Scroll indicator
    render_scroll_indicator(model, list.length(model.files)),
    ui.br(),
    // Footer
    components.footer("[j/k] Navigate  [Enter] Open  [q] Quit"),
  ])
}

/// Render a single file row
fn render_file_row(file: model.FileInfo, is_selected: Bool) -> shore.Node(Msg) {
  let marker = components.selection_marker(is_selected)
  let name = truncate(file.name, 40)
  let count = pad_left(int.to_string(file.test_count), 6)
  let size = pad_left(file.size, 6)

  let line = marker <> pad_right(name, 42) <> " " <> count <> "  " <> size

  case is_selected {
    True -> ui.text_styled(line, Some(style.Black), Some(style.Cyan))
    False -> ui.text(line)
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

fn pad_right(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> s <> string.repeat(" ", width - len)
  }
}

fn pad_left(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> string.repeat(" ", width - len) <> s
  }
}

fn truncate(s: String, max_len: Int) -> String {
  case string.length(s) > max_len {
    True -> string.slice(s, 0, max_len - 3) <> "..."
    False -> s
  }
}
