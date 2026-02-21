/// Renderer for ExpectedEntries (parsed key/value pairs).
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/ansi
import render/theme.{type Theme}
import shore
import shore/ui
import test_types.{type TestEntry}

/// Parts of a rendered entry.
pub type EntryPart {
  OpenParen
  Key(String)
  Comma
  Value(String)
  CloseParen
  Newline
}

/// Convert entries to renderable parts.
pub fn to_parts(entries: List(TestEntry)) -> List(EntryPart) {
  entries
  |> list.flat_map(fn(entry) {
    [OpenParen, Key(entry.key), Comma, Value(entry.value), CloseParen, Newline]
  })
}

/// Render a part to plain string.
fn part_to_string(part: EntryPart) -> String {
  case part {
    OpenParen -> "("
    Key(k) -> k
    Comma -> ", "
    Value(v) -> v
    CloseParen -> ")"
    Newline -> "\n"
  }
}

/// Render entries to plain string (test runner).
pub fn to_string(entries: List(TestEntry)) -> String {
  entries
  |> to_parts
  |> list.map(part_to_string)
  |> string.concat
  |> string.trim_end
}

/// Render entries to ANSI colored string.
pub fn to_ansi(entries: List(TestEntry), theme: Theme) -> String {
  entries
  |> to_parts
  |> list.map(fn(part) {
    case part {
      Key(k) -> ansi.fg(k, theme.key)
      Value(v) -> ansi.fg(v, theme.value)
      _ -> part_to_string(part)
    }
  })
  |> string.concat
  |> string.trim_end
}

/// Render entries to shore nodes (TUI).
pub fn to_shore(entries: List(TestEntry), theme: Theme) -> shore.Node(a) {
  tuples_to_shore(entries |> list.map(fn(e) { #(e.key, e.value) }), theme)
}

/// Render key/value tuples to shore nodes (generic).
pub fn tuples_to_shore(
  tuples: List(#(String, String)),
  theme: Theme,
) -> shore.Node(a) {
  ui.col(
    tuples
    |> list.map(fn(t) {
      let #(key, value) = t
      ui.row([
        ui.text("("),
        ui.text_styled(key, Some(theme.key), None),
        ui.text(", "),
        ui.text_styled(value, Some(theme.value), None),
        ui.text(")"),
      ])
    }),
  )
}

/// Render key/value tuples to plain string.
pub fn tuples_to_string(tuples: List(#(String, String))) -> String {
  tuples
  |> list.map(fn(t) {
    let #(key, value) = t
    "(" <> key <> ", " <> value <> ")"
  })
  |> string.join("\n")
}

/// Render key/value tuples to ANSI colored string.
pub fn tuples_to_ansi(tuples: List(#(String, String)), theme: Theme) -> String {
  tuples
  |> list.map(fn(t) {
    let #(key, value) = t
    "(" <> ansi.fg(key, theme.key) <> ", " <> ansi.fg(value, theme.value) <> ")"
  })
  |> string.join("\n")
}
