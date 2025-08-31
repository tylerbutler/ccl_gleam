/// Shared UI components for the CCL test viewer TUI
import gleam/option.{Some}
import shore
import shore/style
import shore/ui
import tui/msg.{type Msg}

/// Render a header bar
pub fn header(title: String, subtitle: String) -> shore.Node(Msg) {
  ui.box_styled(
    [
      ui.row([
        ui.text_styled(" " <> title <> " ", Some(style.White), Some(style.Blue)),
        ui.text("  "),
        ui.text(subtitle),
      ]),
    ],
    Some("CCL Test Viewer"),
    Some(style.Cyan),
  )
}

/// Render a footer with keybinding hints
pub fn footer(hints: String) -> shore.Node(Msg) {
  ui.row([
    ui.text_styled(" " <> hints <> " ", Some(style.Black), Some(style.White)),
  ])
}

/// Format a selection indicator
pub fn selection_marker(is_selected: Bool) -> String {
  case is_selected {
    True -> "> "
    False -> "  "
  }
}
