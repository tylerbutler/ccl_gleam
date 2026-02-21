/// Renderer for typed expected values (Int, Float, Bool).
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import render/ansi
import render/theme.{type Theme}
import shore
import shore/ui

/// Render an integer value to plain string.
pub fn int_to_string(value: Int) -> String {
  int.to_string(value)
}

/// Render an integer value to ANSI colored string.
pub fn int_to_ansi(value: Int, theme: Theme) -> String {
  ansi.fg(int.to_string(value), theme.value)
}

/// Render an integer value to shore node (TUI).
pub fn int_to_shore(value: Int, theme: Theme) -> shore.Node(a) {
  ui.text_styled(int.to_string(value), Some(theme.value), None)
}

/// Render a float value to plain string.
pub fn float_to_string(value: Float) -> String {
  float.to_string(value)
}

/// Render a float value to ANSI colored string.
pub fn float_to_ansi(value: Float, theme: Theme) -> String {
  ansi.fg(float.to_string(value), theme.value)
}

/// Render a float value to shore node (TUI).
pub fn float_to_shore(value: Float, theme: Theme) -> shore.Node(a) {
  ui.text_styled(float.to_string(value), Some(theme.value), None)
}

/// Render a boolean value to plain string.
pub fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// Render a boolean value to ANSI colored string.
pub fn bool_to_ansi(value: Bool, theme: Theme) -> String {
  ansi.fg(bool_to_string(value), theme.value)
}

/// Render a boolean value to shore node (TUI).
pub fn bool_to_shore(value: Bool, theme: Theme) -> shore.Node(a) {
  ui.text_styled(bool_to_string(value), Some(theme.value), None)
}
