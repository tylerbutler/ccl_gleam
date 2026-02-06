/// Renderer for ExpectedValue (single string values)
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/theme.{type Theme}
import render/whitespace
import shore
import shore/style
import shore/ui

/// Render a string value with visible whitespace to plain string
pub fn to_string(value: String) -> String {
  value
  |> whitespace.visualize
  |> whitespace.to_display_string
}

/// Render a string value with visible whitespace to ANSI colored string
pub fn to_ansi(value: String, theme: Theme) -> String {
  value
  |> whitespace.visualize
  |> list.map(fn(part) {
    case whitespace.is_whitespace(part) {
      True ->
        ansi_color(theme.whitespace) <> whitespace.glyph(part) <> ansi_reset()
      False -> ansi_color(theme.value) <> whitespace.glyph(part) <> ansi_reset()
    }
  })
  |> string.concat
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

/// Render a string value with visible whitespace to shore nodes (TUI)
pub fn to_shore(value: String, theme: Theme) -> shore.Node(a) {
  let parts =
    value
    |> whitespace.visualize
    |> list.map(fn(part) { part_to_shore(part, theme) })

  ui.row(parts)
}

fn part_to_shore(part: whitespace.WhitespacePart, theme: Theme) -> shore.Node(a) {
  case whitespace.is_whitespace(part) {
    True -> ui.text_styled(whitespace.glyph(part), Some(theme.whitespace), None)
    False -> ui.text_styled(whitespace.glyph(part), Some(theme.value), None)
  }
}
