/// Renderer for ExpectedList (list of strings).
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/ansi
import render/theme.{type Theme}
import render/whitespace
import shore
import shore/ui

/// Render a list to plain string with visible whitespace.
/// Format:
/// = item1
/// = item2·with·spaces
pub fn to_string(items: List(String)) -> String {
  items
  |> list.map(fn(item) {
    "= " <> whitespace.visualize(item) |> whitespace.to_display_string
  })
  |> string.join("\n")
}

/// Render a list to ANSI colored string.
pub fn to_ansi(items: List(String), theme: Theme) -> String {
  items
  |> list.map(fn(item) {
    ansi.fg("= ", theme.separator)
    <> whitespace.render_ansi(item, theme.value, theme.whitespace)
  })
  |> string.join("\n")
}

/// Render a list to shore nodes (TUI).
pub fn to_shore(items: List(String), theme: Theme) -> shore.Node(a) {
  ui.col(items |> list.map(fn(item) { item_to_shore(item, theme) }))
}

fn item_to_shore(item: String, theme: Theme) -> shore.Node(a) {
  let parts = whitespace.render_shore(item, theme.value, theme.whitespace)
  ui.row([ui.text_styled("= ", Some(theme.separator), None), parts])
}
