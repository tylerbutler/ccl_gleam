/// Renderer for ExpectedError
import gleam/option.{None, Some}
import shore
import shore/style
import shore/ui

/// Render error indicator to plain string
pub fn to_string() -> String {
  "[ERROR]"
}

/// Render error indicator to ANSI colored string (red)
pub fn to_ansi() -> String {
  "\u{001b}[31m[ERROR]\u{001b}[0m"
}

/// Render error indicator to shore node (TUI, red)
pub fn to_shore() -> shore.Node(a) {
  ui.text_styled("[ERROR]", Some(style.Red), None)
}
