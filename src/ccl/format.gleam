/// CCL Formatting functions.
///
/// Two formatting functions per the docs:
/// - `print`: structure-preserving, operates on entries
///   Property: print(parse(x)) == x for standard-format inputs
/// - `canonical_format`: semantic-preserving, operates on CCL tree
///   Outputs normalized 2-space-indented form
import ccl/types.{
  type CCL, type CCLValue, type Entry, CclList, CclObject, CclString,
}
import gleam/dict
import gleam/list
import gleam/string

/// Structure-preserving format. Converts entries back to CCL text.
///
/// For standard-format inputs: `print(parse(x)) == x`
///
/// Each entry is formatted as `key = value`. If the value contains
/// newlines (nested content), the newlines and indentation are preserved
/// from the original parse.
pub fn print(entries: List(Entry)) -> String {
  entries
  |> list.map(format_entry)
  |> string.join("\n")
}

/// Format a single entry back to CCL text.
fn format_entry(entry: Entry) -> String {
  case entry.value {
    "" -> entry.key <> " = "
    value -> {
      case string.starts_with(value, "\n") {
        // Nested value: key = \n  child = ...
        // The trailing space after = matches the standard format
        True -> entry.key <> " = " <> value
        // Simple value: key = value
        False -> entry.key <> " = " <> value
      }
    }
  }
}

/// Semantic-preserving canonical format. Walks the CCL tree and outputs
/// normalized 2-space-indented form.
///
/// Uses `indent_spaces` behavior (2 spaces per level).
pub fn canonical_format(ccl: CCL) -> String {
  format_dict(ccl, 0)
  |> trim_trailing_newline
}

/// Format a CCL dict at a given indentation level.
fn format_dict(ccl: CCL, indent: Int) -> String {
  let prefix = string.repeat(" ", indent)
  ccl
  |> dict.to_list
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  |> list.map(fn(pair) {
    let #(key, value) = pair
    format_canonical_entry(key, value, prefix, indent)
  })
  |> string.join("\n")
}

/// Format a single key-value pair in canonical form.
fn format_canonical_entry(
  key: String,
  value: CCLValue,
  prefix: String,
  indent: Int,
) -> String {
  case value {
    CclString(s) -> prefix <> key <> " = " <> s
    CclObject(nested) -> {
      let children = format_dict(nested, indent + 2)
      prefix <> key <> " =\n" <> children
    }
    CclList(items) -> {
      items
      |> list.map(fn(item) { format_canonical_list_item(item, prefix, indent) })
      |> string.join("\n")
    }
  }
}

/// Format a list item in canonical form.
fn format_canonical_list_item(
  item: CCLValue,
  prefix: String,
  indent: Int,
) -> String {
  case item {
    CclString(s) -> prefix <> "= " <> s
    CclObject(nested) -> {
      let children = format_dict(nested, indent + 2)
      prefix <> "=\n" <> children
    }
    CclList(_) -> prefix <> "= [nested list]"
  }
}

/// Trim a single trailing newline if present.
fn trim_trailing_newline(s: String) -> String {
  case string.ends_with(s, "\n") {
    True -> string.drop_end(s, 1)
    False -> s
  }
}
