/// Renderer for typed expected values (Int, Float, Bool)
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import render/theme.{type Theme}
import shore
import shore/style
import shore/ui

/// Render an integer value to plain string
pub fn int_to_string(value: Int) -> String {
  int.to_string(value)
}

/// Render an integer value to ANSI colored string
pub fn int_to_ansi(value: Int, theme: Theme) -> String {
  ansi_color(theme.value) <> int.to_string(value) <> ansi_reset()
}

/// Render an integer value to shore node (TUI)
pub fn int_to_shore(value: Int, theme: Theme) -> shore.Node(a) {
  ui.text_styled(int.to_string(value), Some(theme.value), None)
}

/// Render a float value to plain string
pub fn float_to_string(value: Float) -> String {
  float.to_string(value)
}

/// Render a float value to ANSI colored string
pub fn float_to_ansi(value: Float, theme: Theme) -> String {
  ansi_color(theme.value) <> float.to_string(value) <> ansi_reset()
}

/// Render a float value to shore node (TUI)
pub fn float_to_shore(value: Float, theme: Theme) -> shore.Node(a) {
  ui.text_styled(float.to_string(value), Some(theme.value), None)
}

/// Render a boolean value to plain string
pub fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// Render a boolean value to ANSI colored string
pub fn bool_to_ansi(value: Bool, theme: Theme) -> String {
  ansi_color(theme.value) <> bool_to_string(value) <> ansi_reset()
}

/// Render a boolean value to shore node (TUI)
pub fn bool_to_shore(value: Bool, theme: Theme) -> shore.Node(a) {
  ui.text_styled(bool_to_string(value), Some(theme.value), None)
}

fn ansi_color(color: style.Color) -> String {
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
