/// File list view for browsing test files.
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import shore
import shore/style
import shore/ui
import tui/components
import tui/model.{type Model}
import tui/msg.{type Msg}
import util

/// Render the file list view.
pub fn render(model: Model) -> shore.Node(Msg) {
  let #(start, end) = model.visible_bounds(model, list.length(model.files))

  ui.col([
    components.header("Files", "Directory: " <> model.test_dir),
    ui.br(),
    ui.row([
      ui.text_styled(
        "  "
          <> util.pad_right("FILE", 42)
          <> " "
          <> util.pad_left("TESTS", 6)
          <> "  "
          <> util.pad_left("SIZE", 6),
        Some(style.Cyan),
        None,
      ),
    ]),
    ui.hr_styled(style.Blue),
    ui.col(
      model.files
      |> list.index_map(fn(file, idx) { #(file, idx) })
      |> list.filter(fn(pair) { pair.1 >= start && pair.1 < end })
      |> list.map(fn(pair) {
        let #(file, idx) = pair
        render_file_row(file, idx == model.selected_index)
      }),
    ),
    components.scroll_indicator(model, list.length(model.files)),
    ui.br(),
    components.footer("[j/k] Navigate  [Enter] Open  [q] Quit"),
  ])
}

fn render_file_row(file: model.FileInfo, is_selected: Bool) -> shore.Node(Msg) {
  let marker = components.selection_marker(is_selected)
  let name = util.truncate(file.name, 40)
  let count = util.pad_left(int.to_string(file.test_count), 6)
  let size = util.pad_left(file.size, 6)

  let line = marker <> util.pad_right(name, 42) <> " " <> count <> "  " <> size

  case is_selected {
    True -> ui.text_styled(line, Some(style.Black), Some(style.Cyan))
    False -> ui.text(line)
  }
}
