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
      ui.text(
        ansi_fg(style.Yellow)
        <> " "
        <> title
        <> " "
        <> ansi_reset()
        <> "  "
        <> subtitle,
      ),
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
