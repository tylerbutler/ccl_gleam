/// Renderer for ExpectedList (list of strings)
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/theme.{type Theme}
import render/whitespace
import shore
import shore/style
import shore/ui

/// Render a list to plain string with visible whitespace
/// Format:
/// = item1
/// = item2·with·spaces
pub fn to_string(items: List(String)) -> String {
  items
  |> list.map(fn(item) { "= " <> item_to_display(item) })
  |> string.join("\n")
}

/// Render a list to ANSI colored string
pub fn to_ansi(items: List(String), theme: Theme) -> String {
  items
  |> list.map(fn(item) {
    ansi_color(theme.separator)
    <> "= "
    <> ansi_reset()
    <> item_to_ansi(item, theme)
  })
  |> string.join("\n")
}

/// Render a list to shore nodes (TUI)
pub fn to_shore(items: List(String), theme: Theme) -> shore.Node(a) {
  ui.col(items |> list.map(fn(item) { item_to_shore(item, theme) }))
}

fn item_to_display(item: String) -> String {
  item
  |> whitespace.visualize
  |> whitespace.to_display_string
}

fn item_to_ansi(item: String, theme: Theme) -> String {
  item
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

fn item_to_shore(item: String, theme: Theme) -> shore.Node(a) {
  let parts =
    item
    |> whitespace.visualize
    |> list.map(fn(part) {
      case whitespace.is_whitespace(part) {
        True ->
          ui.text_styled(whitespace.glyph(part), Some(theme.whitespace), None)
        False -> ui.text_styled(whitespace.glyph(part), Some(theme.value), None)
      }
    })

  ui.row([ui.text_styled("= ", Some(theme.separator), None), ..parts])
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
