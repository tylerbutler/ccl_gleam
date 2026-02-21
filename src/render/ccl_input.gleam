/// Renderer for raw CCL input with visible whitespace.
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/ansi
import render/theme.{type Theme}
import render/whitespace.{type WhitespacePart}
import shore
import shore/ui

/// Parts of a CCL line.
pub type CclPart {
  Key(String)
  Separator
  Value(String)
  Whitespace(WhitespacePart)
}

/// Parse a single CCL line into parts.
/// Handles format: key = value (with optional whitespace).
fn parse_line(line: String) -> List(CclPart) {
  case string.split_once(line, "=") {
    Ok(#(before_eq, after_eq)) -> {
      let key_parts = parse_with_whitespace(string.trim_end(before_eq), Key)
      let trailing_ws = get_trailing_whitespace(before_eq)
      let value_parts =
        parse_with_whitespace(string.trim_start(after_eq), Value)
      let leading_ws = get_leading_whitespace(after_eq)

      list.flatten([
        key_parts,
        trailing_ws,
        [Separator],
        leading_ws,
        value_parts,
      ])
    }
    Error(_) -> parse_with_whitespace(line, Value)
  }
}

/// Parse text and convert whitespace to parts.
fn parse_with_whitespace(
  text: String,
  wrapper: fn(String) -> CclPart,
) -> List(CclPart) {
  text
  |> whitespace.visualize
  |> list.map(fn(part) {
    case part {
      whitespace.Text(s) -> wrapper(s)
      ws -> Whitespace(ws)
    }
  })
}

/// Get trailing whitespace from a string as parts.
fn get_trailing_whitespace(s: String) -> List(CclPart) {
  let trimmed = string.trim_end(s)
  string.drop_start(s, string.length(trimmed))
  |> whitespace.visualize
  |> list.map(Whitespace)
}

/// Get leading whitespace from a string as parts.
fn get_leading_whitespace(s: String) -> List(CclPart) {
  let trimmed = string.trim_start(s)
  let leading_len = string.length(s) - string.length(trimmed)
  s
  |> string.slice(0, leading_len)
  |> whitespace.visualize
  |> list.map(Whitespace)
}

/// Parse CCL input into renderable parts (line by line).
pub fn to_parts(input: String) -> List(List(CclPart)) {
  input
  |> string.split("\n")
  |> list.map(parse_line)
}

/// Render part to plain string.
fn part_to_string(part: CclPart) -> String {
  case part {
    Key(k) -> k
    Separator -> "="
    Value(v) -> v
    Whitespace(ws) -> whitespace.glyph(ws)
  }
}

/// Render CCL input to plain string with visible whitespace.
pub fn to_string(input: String) -> String {
  input
  |> to_parts
  |> list.map(fn(line_parts) {
    line_parts |> list.map(part_to_string) |> string.concat
  })
  |> string.join("↵\n")
}

/// Render CCL input to ANSI colored string with visible whitespace.
pub fn to_ansi(input: String, theme: Theme) -> String {
  input
  |> to_parts
  |> list.map(fn(line_parts) {
    line_parts
    |> list.map(fn(part) { part_to_ansi(part, theme) })
    |> string.concat
  })
  |> string.join(ansi.fg("↵", theme.whitespace) <> "\n")
}

fn part_to_ansi(part: CclPart, theme: Theme) -> String {
  case part {
    Key(k) -> ansi.fg(k, theme.key)
    Separator -> ansi.fg("=", theme.separator)
    Value(v) -> ansi.fg(v, theme.value)
    Whitespace(ws) -> ansi.fg(whitespace.glyph(ws), theme.whitespace)
  }
}

/// Render CCL input to shore nodes (TUI).
pub fn to_shore(input: String, theme: Theme) -> shore.Node(a) {
  ui.col(
    input
    |> to_parts
    |> list.map(fn(line_parts) { line_to_shore(line_parts, theme) }),
  )
}

fn line_to_shore(parts: List(CclPart), theme: Theme) -> shore.Node(a) {
  let nodes = parts |> list.map(fn(part) { part_to_shore(part, theme) })
  let with_newline =
    list.append(nodes, [
      ui.text_styled("↵", Some(theme.whitespace), None),
    ])
  ui.row(with_newline)
}

fn part_to_shore(part: CclPart, theme: Theme) -> shore.Node(a) {
  case part {
    Key(k) -> ui.text_styled(k, Some(theme.key), None)
    Separator -> ui.text_styled("=", Some(theme.separator), None)
    Value(v) -> ui.text_styled(v, Some(theme.value), None)
    Whitespace(ws) ->
      ui.text_styled(whitespace.glyph(ws), Some(theme.whitespace), None)
  }
}
