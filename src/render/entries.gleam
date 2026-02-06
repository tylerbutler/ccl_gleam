/// Renderer for ExpectedEntries (parsed key/value pairs)
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/theme.{type Theme}
import shore
import shore/style
import shore/ui
import test_types.{type TestEntry}

/// Parts of a rendered entry
pub type EntryPart {
  OpenParen
  Key(String)
  Comma
  Value(String)
  CloseParen
  Newline
}

/// Convert a single entry to renderable parts
fn entry_to_parts(entry: TestEntry) -> List(EntryPart) {
  [OpenParen, Key(entry.key), Comma, Value(entry.value), CloseParen]
}

/// Convert entries to renderable parts
pub fn to_parts(entries: List(TestEntry)) -> List(EntryPart) {
  entries
  |> list.flat_map(fn(entry) { list.append(entry_to_parts(entry), [Newline]) })
}

/// Render a part to plain string
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

/// Render entries to plain string (test runner)
pub fn to_string(entries: List(TestEntry)) -> String {
  entries
  |> to_parts
  |> list.map(part_to_string)
  |> string.concat
  |> string.trim_end
}

/// Render entries to ANSI colored string
pub fn to_ansi(entries: List(TestEntry), theme: Theme) -> String {
  entries
  |> to_parts
  |> list.map(fn(part) { part_to_ansi(part, theme) })
  |> string.concat
  |> string.trim_end
}

fn part_to_ansi(part: EntryPart, theme: Theme) -> String {
  case part {
    Key(k) -> ansi_color(theme.key) <> k <> ansi_reset()
    Value(v) -> ansi_color(theme.value) <> v <> ansi_reset()
    _ -> part_to_string(part)
  }
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

/// Render entries to shore nodes (TUI)
pub fn to_shore(entries: List(TestEntry), theme: Theme) -> shore.Node(a) {
  tuples_to_shore(entries |> list.map(fn(e) { #(e.key, e.value) }), theme)
}

/// Render key/value tuples to shore nodes (generic)
pub fn tuples_to_shore(
  tuples: List(#(String, String)),
  theme: Theme,
) -> shore.Node(a) {
  ui.col(tuples |> list.map(fn(t) { tuple_to_shore(t, theme) }))
}

fn tuple_to_shore(t: #(String, String), theme: Theme) -> shore.Node(a) {
  let #(key, value) = t
  ui.row([
    ui.text("("),
    ui.text_styled(key, Some(theme.key), None),
    ui.text(", "),
    ui.text_styled(value, Some(theme.value), None),
    ui.text(")"),
  ])
}

// Generic tuple-based functions for use by test_runner

/// Render key/value tuples to plain string
pub fn tuples_to_string(tuples: List(#(String, String))) -> String {
  tuples
  |> list.map(fn(t) {
    let #(key, value) = t
    "(" <> key <> ", " <> value <> ")"
  })
  |> string.join("\n")
}

/// Render key/value tuples to ANSI colored string
pub fn tuples_to_ansi(tuples: List(#(String, String)), theme: Theme) -> String {
  tuples
  |> list.map(fn(t) {
    let #(key, value) = t
    "("
    <> ansi_color(theme.key)
    <> key
    <> ansi_reset()
    <> ", "
    <> ansi_color(theme.value)
    <> value
    <> ansi_reset()
    <> ")"
  })
  |> string.join("\n")
}
