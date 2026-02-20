/// Side-by-side expected/actual diff rendering
///
/// Lays out expected and actual columns horizontally with visible whitespace.
/// Used by the test runner to format mismatch messages.
import gleam/int
import gleam/list
import gleam/string
import render/theme.{type Theme}
import render/whitespace
import shore/style

// ============================================================================
// ANSI helpers
// ============================================================================

const reset = "\u{001b}[0m"

const bold = "\u{001b}[1m"

const dim = "\u{001b}[2m"

const green_bg = "\u{001b}[42;30m"

const red_bg = "\u{001b}[41;37m"

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

// ============================================================================
// Entry rendering with visible whitespace
// ============================================================================

/// Render a single entry as multiple display lines.
/// The first line shows `(key, value-line-1` and subsequent value lines
/// are continuation lines indented to align under the value.
/// The closing `)` goes on the last line.
fn entry_to_lines(key: String, value: String, theme: Theme) -> List(String) {
  let key_vis = ws_ansi(key, ansi_color(theme.key))
  let prefix = "(" <> key_vis <> dim <> ", " <> reset

  let value_lines = string.split(value, "\n")
  case value_lines {
    // Single-line value
    [single] -> [prefix <> ws_ansi(single, ansi_color(theme.value)) <> ")"]
    // Multi-line value: first line gets prefix, rest are indented continuations
    [first, ..rest] -> {
      let first_line =
        prefix <> ws_ansi(first, ansi_color(theme.value)) <> dim <> "↵" <> reset
      let continuation_lines =
        rest
        |> list.index_map(fn(line, idx) {
          let is_last = idx == list.length(rest) - 1
          let content = ws_ansi(line, ansi_color(theme.value))
          let suffix = case is_last {
            True -> ")"
            False -> dim <> "↵" <> reset
          }
          "  " <> content <> suffix
        })
      [first_line, ..continuation_lines]
    }
    // Empty (shouldn't happen)
    [] -> [prefix <> ")"]
  }
}

// ============================================================================
// Side-by-side diff: entries
// ============================================================================

/// Format an entries mismatch as a side-by-side diff.
pub fn entries_diff(
  expected: List(#(String, String)),
  actual: List(#(String, String)),
  theme: Theme,
) -> String {
  let expected_lines =
    expected |> list.flat_map(fn(t) { entry_to_lines(t.0, t.1, theme) })
  let actual_lines =
    actual |> list.flat_map(fn(t) { entry_to_lines(t.0, t.1, theme) })

  side_by_side("expected", expected_lines, "actual", actual_lines)
}

// ============================================================================
// Side-by-side diff: single values (print mismatch)
// ============================================================================

/// Format a single-value mismatch (print tests) side-by-side.
/// Splits on actual newlines in the value to show line-by-line comparison.
pub fn value_diff(
  expected: String,
  actual: String,
  theme: Theme,
) -> String {
  let expected_lines = value_to_lines(expected, theme)
  let actual_lines = value_to_lines(actual, theme)

  side_by_side("expected", expected_lines, "actual", actual_lines)
}

/// Split a value into display lines, rendering each line with visible whitespace.
/// Non-final lines get a trailing `↵` glyph to mark the line break.
fn value_to_lines(value: String, theme: Theme) -> List(String) {
  let lines = string.split(value, "\n")
  let last_idx = list.length(lines) - 1
  lines
  |> list.index_map(fn(line, idx) {
    let rendered = ws_ansi(line, ansi_color(theme.value))
    case idx < last_idx {
      True -> rendered <> dim <> "↵" <> reset
      False -> rendered
    }
  })
}

/// Format a typed value mismatch side-by-side (inline).
pub fn inline_diff(
  expected: String,
  actual: String,
) -> String {
  green_bg
  <> " expected "
  <> reset
  <> " "
  <> expected
  <> "    "
  <> red_bg
  <> " actual "
  <> reset
  <> " "
  <> actual
}

// ============================================================================
// Side-by-side diff: multi-line blocks (objects, lists)
// ============================================================================

/// Format a multi-line block mismatch side-by-side.
pub fn block_diff(
  expected_lines: List(String),
  actual_lines: List(String),
) -> String {
  side_by_side("expected", expected_lines, "actual", actual_lines)
}

// ============================================================================
// Core side-by-side layout
// ============================================================================

/// Lay out two sets of lines side-by-side with headers.
///
/// ```
/// ┌ expected ┐             │ ┌ actual ┐
/// (key, value)             │ (key, value)
/// (other, thing)           │ (other, different)
///                          │ (extra, line)
/// ```
fn side_by_side(
  left_label: String,
  left_lines: List(String),
  right_label: String,
  right_lines: List(String),
) -> String {
  // Calculate column width from the visible (non-ANSI) length of left lines
  let left_widths = left_lines |> list.map(fn(l) { visible_length(l) })
  let label_width = string.length(left_label) + 2

  let max_left = [label_width, ..left_widths] |> list.fold(0, int.max)

  // Clamp column width to avoid absurd widths
  let col_width = int.min(int.max(max_left + 2, 20), 50)

  let sep = dim <> " │ " <> reset

  // Header
  let header =
    bold
    <> green_bg
    <> " "
    <> left_label
    <> " "
    <> reset
    <> pad_to(label_width, col_width)
    <> sep
    <> bold
    <> red_bg
    <> " "
    <> right_label
    <> " "
    <> reset

  // Pad lines to equal length
  let left_count = list.length(left_lines)
  let right_count = list.length(right_lines)
  let max_count = int.max(left_count, right_count)

  let left_padded = pad_list(left_lines, max_count)
  let right_padded = pad_list(right_lines, max_count)

  let body_lines =
    list.zip(left_padded, right_padded)
    |> list.map(fn(pair) {
      let #(l, r) = pair
      let l_vis_len = visible_length(l)
      let padding = case col_width > l_vis_len {
        True -> string.repeat(" ", col_width - l_vis_len)
        False -> "  "
      }
      l <> padding <> sep <> r
    })

  [header, ..body_lines] |> string.join("\n")
}

/// Generate padding from a current width to a target width.
fn pad_to(current: Int, target: Int) -> String {
  case target > current {
    True -> string.repeat(" ", target - current)
    False -> ""
  }
}

/// Pad a list with empty strings to reach the target length.
fn pad_list(lines: List(String), target: Int) -> List(String) {
  let current = list.length(lines)
  case current >= target {
    True -> lines
    False -> list.append(lines, list.repeat("", target - current))
  }
}

// ============================================================================
// Whitespace visualization
// ============================================================================

/// Render a string with visible whitespace glyphs.
/// Whitespace chars get dim styling; text gets the given color.
fn ws_ansi(s: String, text_color: String) -> String {
  let ws_color = dim

  s
  |> whitespace.visualize
  |> list.map(fn(part) {
    case whitespace.is_whitespace(part) {
      True -> ws_color <> whitespace.glyph(part) <> reset
      False -> text_color <> whitespace.glyph(part) <> reset
    }
  })
  |> string.concat
}

// ============================================================================
// Visible string length (strip ANSI escapes)
// ============================================================================

/// Calculate the visible length of a string, ignoring ANSI escape sequences.
fn visible_length(s: String) -> Int {
  s
  |> strip_ansi
  |> string.length
}

/// Strip ANSI escape sequences from a string.
fn strip_ansi(s: String) -> String {
  strip_ansi_loop(s, "", False)
}

fn strip_ansi_loop(remaining: String, acc: String, in_escape: Bool) -> String {
  case string.pop_grapheme(remaining) {
    Error(_) -> acc
    Ok(#(char, rest)) -> {
      case in_escape {
        True -> {
          case is_letter(char) {
            True -> strip_ansi_loop(rest, acc, False)
            False -> strip_ansi_loop(rest, acc, True)
          }
        }
        False -> {
          case char == "\u{001b}" {
            True -> strip_ansi_loop(rest, acc, True)
            False -> strip_ansi_loop(rest, acc <> char, False)
          }
        }
      }
    }
  }
}

fn is_letter(char: String) -> Bool {
  case char {
    "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l"
    | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x"
    | "y" | "z" | "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
    | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V"
    | "W" | "X" | "Y" | "Z" -> True
    _ -> False
  }
}
