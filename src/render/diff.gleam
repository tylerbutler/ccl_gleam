/// Side-by-side expected/actual diff rendering.
///
/// Lays out expected and actual columns horizontally with visible whitespace.
/// Used by the test runner to format mismatch messages.
import gleam/int
import gleam/list
import gleam/string
import render/ansi
import render/theme.{type Theme}
import render/whitespace

// ============================================================================
// Entry rendering with visible whitespace
// ============================================================================

/// Render a single entry as multiple display lines.
fn entry_to_lines(key: String, value: String, theme: Theme) -> List(String) {
  let key_vis = whitespace.render_ansi_dim_ws(key, theme.key)
  let prefix = "(" <> key_vis <> ansi.dim(", ")

  let value_lines = string.split(value, "\n")
  case value_lines {
    [single] -> [
      prefix <> whitespace.render_ansi_dim_ws(single, theme.value) <> ")",
    ]
    [first, ..rest] -> {
      let first_line =
        prefix
        <> whitespace.render_ansi_dim_ws(first, theme.value)
        <> ansi.dim("↵")
      let continuation_lines =
        rest
        |> list.index_map(fn(line, idx) {
          let is_last = idx == list.length(rest) - 1
          let content = whitespace.render_ansi_dim_ws(line, theme.value)
          let suffix = case is_last {
            True -> ")"
            False -> ansi.dim("↵")
          }
          "  " <> content <> suffix
        })
      [first_line, ..continuation_lines]
    }
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
  let expected_count = list.length(expected)
  let actual_count = list.length(actual)
  let expected_lines =
    expected |> list.flat_map(fn(t) { entry_to_lines(t.0, t.1, theme) })
  let actual_lines =
    actual |> list.flat_map(fn(t) { entry_to_lines(t.0, t.1, theme) })

  side_by_side(
    "expected (" <> int.to_string(expected_count) <> ")",
    expected_lines,
    "actual (" <> int.to_string(actual_count) <> ")",
    actual_lines,
  )
}

// ============================================================================
// Side-by-side diff: single values (print mismatch)
// ============================================================================

/// Format a single-value mismatch (print tests) side-by-side.
pub fn value_diff(expected: String, actual: String, theme: Theme) -> String {
  let expected_lines = value_to_lines(expected, theme)
  let actual_lines = value_to_lines(actual, theme)
  side_by_side("expected", expected_lines, "actual", actual_lines)
}

/// Split a value into display lines with visible whitespace.
fn value_to_lines(value: String, theme: Theme) -> List(String) {
  let lines = string.split(value, "\n")
  let last_idx = list.length(lines) - 1
  lines
  |> list.index_map(fn(line, idx) {
    let rendered = whitespace.render_ansi_dim_ws(line, theme.value)
    case idx < last_idx {
      True -> rendered <> ansi.dim("↵")
      False -> rendered
    }
  })
}

/// Format a typed value mismatch side-by-side (inline).
pub fn inline_diff(expected: String, actual: String) -> String {
  ansi.bg_green(" expected ")
  <> " "
  <> expected
  <> "    "
  <> ansi.bg_red(" actual ")
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

fn side_by_side(
  left_label: String,
  left_lines: List(String),
  right_label: String,
  right_lines: List(String),
) -> String {
  let left_widths = left_lines |> list.map(ansi.visible_length)
  let label_width = string.length(left_label) + 2

  let max_left = [label_width, ..left_widths] |> list.fold(0, int.max)
  let col_width = int.min(int.max(max_left + 2, 20), 50)

  let sep = ansi.dim(" │ ")

  // Header
  let header =
    ansi.bold(ansi.bg_green(" " <> left_label <> " "))
    <> pad_to(label_width, col_width)
    <> sep
    <> ansi.bold(ansi.bg_red(" " <> right_label <> " "))

  // Pad lines to equal length
  let max_count = int.max(list.length(left_lines), list.length(right_lines))
  let left_padded = pad_list(left_lines, max_count)
  let right_padded = pad_list(right_lines, max_count)

  let body_lines =
    list.zip(left_padded, right_padded)
    |> list.map(fn(pair) {
      let #(l, r) = pair
      let l_vis_len = ansi.visible_length(l)
      let padding = case col_width > l_vis_len {
        True -> string.repeat(" ", col_width - l_vis_len)
        False -> "  "
      }
      l <> padding <> sep <> r
    })

  [header, ..body_lines] |> string.join("\n")
}

fn pad_to(current: Int, target: Int) -> String {
  case target > current {
    True -> string.repeat(" ", target - current)
    False -> ""
  }
}

fn pad_list(lines: List(String), target: Int) -> List(String) {
  let current = list.length(lines)
  case current >= target {
    True -> lines
    False -> list.append(lines, list.repeat("", target - current))
  }
}
