/// CCL Parser — indentation-aware entry parsing.
///
/// Implements the CCL parsing algorithm from the docs:
/// 1. Find first `=` on a line to split key from value
/// 2. Track indentation to detect continuation lines (indent > baseline N)
/// 3. Two parsing contexts:
///    - Top-level (`parse`): N = 0 (`toplevel_indent_strip` behavior)
///    - Nested (`parse_value`): N = first content line's indentation
///
/// Behaviors implemented:
/// - `toplevel_indent_strip`: top-level baseline is always 0
/// - `crlf_normalize_to_lf`: normalize \r\n to \n before parsing
/// - `tabs_as_whitespace`: both spaces and tabs count as whitespace
import ccl/types.{type Entry, Entry}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Parse top-level CCL text into flat entries.
/// Uses `toplevel_indent_strip`: baseline N = 0.
/// Applies `tabs_as_whitespace`: all tabs replaced with spaces.
pub fn parse(text: String) -> Result(List(Entry), String) {
  let normalized = normalize_line_endings(text)
  let tab_normalized = normalize_tabs(normalized)
  parse_with_baseline(tab_normalized, 0)
}

/// Parse a nested value (called by build_hierarchy during recursive parsing).
/// If text starts with \n, detects baseline from first content line's indentation.
/// Otherwise parses as a single-line value.
/// Matches OCaml's `parse_value` / `nested_kvs_p`.
pub fn parse_value(text: String) -> Result(List(Entry), String) {
  case string.first(text) {
    // Nested context: skip leading newline, detect baseline from first content line
    Ok("\n") -> {
      let rest = string.drop_start(text, 1)
      let baseline = detect_baseline(rest)
      parse_with_baseline(rest, baseline)
    }
    // Single-line or empty: parse with baseline 0
    Ok(_) -> parse_with_baseline(text, 0)
    // Empty string
    Error(_) -> Ok([])
  }
}

/// Core parsing loop. Splits text into entries using the given baseline N.
/// A line is a continuation if its indentation > N.
fn parse_with_baseline(
  text: String,
  baseline: Int,
) -> Result(List(Entry), String) {
  let lines = string.split(text, "\n")
  parse_lines(lines, baseline, [], None)
}

/// State machine for parsing lines into entries.
/// Accumulates continuation lines into the current entry's value.
fn parse_lines(
  lines: List(String),
  baseline: Int,
  acc: List(Entry),
  current: Option(#(String, List(String))),
) -> Result(List(Entry), String) {
  case lines {
    [] -> {
      // Flush any remaining entry
      let final_acc = flush_entry(acc, current)
      Ok(list.reverse(final_acc))
    }
    [line, ..rest] -> {
      let indent = count_leading_whitespace(line)
      let trimmed = string.trim(line)

      case trimmed {
        // Empty line: preserve within continuations, skip otherwise
        "" -> {
          case current {
            Some(#(key, value_lines)) -> {
              // Check if there are more continuation lines after this empty line
              case has_continuation_after(rest, baseline) {
                True -> {
                  // Preserve empty line within the value
                  let new_current = Some(#(key, list.append(value_lines, [""])))
                  parse_lines(rest, baseline, acc, new_current)
                }
                False -> {
                  // End of value, flush and continue
                  let new_acc = flush_entry(acc, current)
                  parse_lines(rest, baseline, new_acc, None)
                }
              }
            }
            None -> {
              // Skip standalone empty lines
              parse_lines(rest, baseline, acc, None)
            }
          }
        }
        _ -> {
          case indent > baseline, current {
            // Continuation line: append to current entry's value
            True, Some(#(key, value_lines)) -> {
              let new_current = Some(#(key, list.append(value_lines, [line])))
              parse_lines(rest, baseline, acc, new_current)
            }
            // Continuation line but no current entry: treat as new entry
            // This handles the case where indented text appears at the start
            True, None -> {
              case split_on_equals(line) {
                Ok(#(key, value)) -> {
                  let new_current = Some(#(key, [value]))
                  parse_lines(rest, baseline, acc, new_current)
                }
                // Line without '=' at continuation level — treat as continuation
                // of nothing, skip it (shouldn't normally happen at start)
                Error(_) -> parse_lines(rest, baseline, acc, None)
              }
            }
            // New entry (indent <= baseline): flush current, start new
            False, _ -> {
              let new_acc = flush_entry(acc, current)
              case split_on_equals(line) {
                Ok(#(key, value)) -> {
                  let new_current = Some(#(key, [value]))
                  parse_lines(rest, baseline, new_acc, new_current)
                }
                // Line without '=' at entry level — skip
                Error(_) -> parse_lines(rest, baseline, new_acc, None)
              }
            }
          }
        }
      }
    }
  }
}

/// Flush the current entry (if any) into the accumulator.
fn flush_entry(
  acc: List(Entry),
  current: Option(#(String, List(String))),
) -> List(Entry) {
  case current {
    None -> acc
    Some(#(key, value_lines)) -> {
      let value = build_value(value_lines)
      [Entry(key: key, value: value), ..acc]
    }
  }
}

/// Build the final value string from accumulated lines.
/// First line has leading whitespace already trimmed.
/// Trailing whitespace on the final line is trimmed.
fn build_value(lines: List(String)) -> String {
  case lines {
    [] -> ""
    [single] -> trim_trailing(single)
    [first, ..rest] -> {
      // Join all lines with newlines
      let joined = string.join([first, ..rest], "\n")
      // Trim trailing whitespace from the final result
      trim_trailing(joined)
    }
  }
}

/// Split a line on the first `=` character.
/// Returns (trimmed_key, trimmed_first_line_value).
fn split_on_equals(line: String) -> Result(#(String, String), Nil) {
  case string.split_once(line, "=") {
    Ok(#(raw_key, raw_value)) -> {
      let key = trim_key(raw_key)
      let value = trim_leading_whitespace(raw_value)
      Ok(#(key, value))
    }
    Error(_) -> Error(Nil)
  }
}

/// Trim all whitespace from a key (including internal newlines).
/// Per the docs: "Trim all whitespace from keys (including newlines)"
fn trim_key(raw: String) -> String {
  string.trim(raw)
}

/// Trim leading whitespace (spaces and tabs) from a string.
/// Used for the value portion after `=`.
fn trim_leading_whitespace(s: String) -> String {
  case string.first(s) {
    Ok(" ") -> trim_leading_whitespace(string.drop_start(s, 1))
    Ok("\t") -> trim_leading_whitespace(string.drop_start(s, 1))
    _ -> s
  }
}

/// Trim trailing whitespace from a string.
fn trim_trailing(s: String) -> String {
  case string.last(s) {
    Ok(" ") -> trim_trailing(string.drop_end(s, 1))
    Ok("\t") -> trim_trailing(string.drop_end(s, 1))
    Ok("\n") -> trim_trailing(string.drop_end(s, 1))
    _ -> s
  }
}

/// Count leading whitespace characters (spaces and tabs).
/// Per `tabs_as_whitespace` behavior: both count.
fn count_leading_whitespace(line: String) -> Int {
  count_ws_chars(string.to_graphemes(line), 0)
}

fn count_ws_chars(chars: List(String), count: Int) -> Int {
  case chars {
    [" ", ..rest] -> count_ws_chars(rest, count + 1)
    ["\t", ..rest] -> count_ws_chars(rest, count + 1)
    _ -> count
  }
}

/// Detect the baseline indentation from the first non-empty line.
/// Used for nested parsing context.
fn detect_baseline(text: String) -> Int {
  let lines = string.split(text, "\n")
  find_first_content_indent(lines)
}

fn find_first_content_indent(lines: List(String)) -> Int {
  case lines {
    [] -> 0
    [line, ..rest] -> {
      case string.trim(line) {
        "" -> find_first_content_indent(rest)
        _ -> count_leading_whitespace(line)
      }
    }
  }
}

/// Check if any line after the current position has indent > baseline,
/// indicating more continuation content follows an empty line.
fn has_continuation_after(lines: List(String), baseline: Int) -> Bool {
  case lines {
    [] -> False
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case trimmed {
        // Skip empty lines, keep looking
        "" -> has_continuation_after(rest, baseline)
        _ -> {
          let indent = count_leading_whitespace(line)
          indent > baseline
        }
      }
    }
  }
}

/// Normalize CRLF line endings to LF.
/// Per `crlf_normalize_to_lf` behavior.
fn normalize_line_endings(text: String) -> String {
  string.replace(text, "\r\n", "\n")
}

/// Normalize tabs to spaces.
/// Per `tabs_as_whitespace` behavior: all tabs are replaced with spaces.
fn normalize_tabs(text: String) -> String {
  string.replace(text, "\t", " ")
}
