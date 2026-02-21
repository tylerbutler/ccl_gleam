/// Shared UI components for the CCL test viewer TUI.
import gleam/int
import gleam/option.{None, Some}
import render/ansi
import shore
import shore/style
import shore/ui
import tui/model.{type Model}
import tui/msg.{type Msg}

/// Render a header bar.
pub fn header(title: String, subtitle: String) -> shore.Node(Msg) {
  ui.box_styled(
    [
      ui.text(ansi.fg(" " <> title <> " ", style.Yellow) <> "  " <> subtitle),
    ],
    Some("CCL Test Viewer"),
    Some(style.Cyan),
  )
}

/// Render a footer with keybinding hints.
pub fn footer(hints: String) -> shore.Node(Msg) {
  ui.row([
    ui.text_styled(" " <> hints <> " ", Some(style.Black), Some(style.White)),
  ])
}

/// Format a selection indicator.
pub fn selection_marker(is_selected: Bool) -> String {
  case is_selected {
    True -> "> "
    False -> "  "
  }
}

/// Render scroll indicator (shared between file_list and test_list views).
pub fn scroll_indicator(model: Model, total: Int) -> shore.Node(Msg) {
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
