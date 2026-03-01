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
import ccl/types.{
  type Entry, type ParseOptions, DelimiterPreferSpaced, Entry, IndentPreserve,
  IndentStrip, NormalizeToLf, TabsAsContent, TabsAsWhitespace,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Parse top-level CCL text into flat entries using default options.
pub fn parse(text: String) -> Result(List(Entry), String) {
  parse_with(text, types.default_parse_options())
}

/// Parse top-level CCL text into flat entries with configurable options.
pub fn parse_with(
  text: String,
  options: ParseOptions,
) -> Result(List(Entry), String) {
  let normalized = case options.line_endings {
    NormalizeToLf -> normalize_line_endings(text)
    _ -> text
  }
  let baseline = case options.continuation_baseline {
    IndentStrip -> 0
    IndentPreserve -> detect_baseline(normalized)
  }
  parse_with_baseline(normalized, baseline, options)
}

/// Parse indented CCL text by auto-detecting the baseline indentation.
/// Unlike `parse` which uses N=0, this detects the baseline from the first
/// content line's indentation, allowing pre-indented text to be parsed correctly.
@internal
pub fn parse_indented(text: String) -> Result(List(Entry), String) {
  parse_indented_with(text, types.default_parse_options())
}

/// Parse indented CCL text with configurable options.
@internal
pub fn parse_indented_with(
  text: String,
  options: ParseOptions,
) -> Result(List(Entry), String) {
  let normalized = case options.line_endings {
    NormalizeToLf -> normalize_line_endings(text)
    _ -> text
  }
  let baseline = detect_baseline(normalized)
  parse_with_baseline(normalized, baseline, options)
}

/// Parse a nested value (called by build_hierarchy during recursive parsing).
/// If text starts with \n, detects baseline from first content line's indentation.
/// Otherwise parses as a single-line value.
/// Matches OCaml's `parse_value` / `nested_kvs_p`.
pub fn parse_value(text: String) -> Result(List(Entry), String) {
  parse_value_with(text, types.default_parse_options())
}

/// Parse a nested value with configurable options.
pub fn parse_value_with(
  text: String,
  options: ParseOptions,
) -> Result(List(Entry), String) {
  case string.first(text) {
    // Nested context: skip leading newline, detect baseline from first content line
    Ok("\n") -> {
      let rest = string.drop_start(text, 1)
      let baseline = detect_baseline(rest)
      parse_with_baseline(rest, baseline, options)
    }
    // Single-line or empty: parse with baseline 0
    Ok(_) -> parse_with_baseline(text, 0, options)
    // Empty string
    Error(_) -> Ok([])
  }
}

/// Core parsing loop. Splits text into entries using the given baseline N.
/// A line is a continuation if its indentation > N.
fn parse_with_baseline(
  text: String,
  baseline: Int,
  options: ParseOptions,
) -> Result(List(Entry), String) {
  let lines = string.split(text, "\n")
  parse_lines(lines, baseline, [], None, None, options)
}

/// State machine for parsing lines into entries.
/// Accumulates continuation lines into the current entry's value.
///
/// `pending_key`: buffered text from lines without `=`, to be combined
/// with the next line that has `=`. This mirrors OCaml's `many (not_char '=')`
/// which reads across line boundaries until it hits `=`.
fn parse_lines(
  lines: List(String),
  baseline: Int,
  acc: List(Entry),
  current: Option(#(String, List(String))),
  pending_key: Option(String),
  options: ParseOptions,
) -> Result(List(Entry), String) {
  case lines {
    [] -> {
      // Flush any remaining entry (pending_key without `=` is discarded)
      let final_acc = flush_entry(acc, current, options)
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
                  parse_lines(
                    rest,
                    baseline,
                    acc,
                    new_current,
                    pending_key,
                    options,
                  )
                }
                False -> {
                  // End of value, flush and continue
                  let new_acc = flush_entry(acc, current, options)
                  parse_lines(rest, baseline, new_acc, None, pending_key, options)
                }
              }
            }
            None -> {
              // Skip standalone empty lines
              parse_lines(rest, baseline, acc, None, pending_key, options)
            }
          }
        }
        _ -> {
          case indent > baseline, current {
            // Continuation line: append to current entry's value
            True, Some(#(key, value_lines)) -> {
              let new_current = Some(#(key, list.append(value_lines, [line])))
              parse_lines(rest, baseline, acc, new_current, None, options)
            }
            // Continuation line but no current entry: treat as new entry
            // This handles the case where indented text appears at the start
            True, None -> {
              case split_on_equals_with(line, options) {
                Ok(#(key, value)) -> {
                  let new_current = Some(#(key, [value]))
                  parse_lines(rest, baseline, acc, new_current, None, options)
                }
                // Line without '=' — buffer as pending key
                Error(_) ->
                  parse_lines(rest, baseline, acc, None, Some(trimmed), options)
              }
            }
            // New entry (indent <= baseline): flush current, start new
            False, _ -> {
              let new_acc = flush_entry(acc, current, options)
              case split_on_equals_with(line, options) {
                Ok(#(key, value)) -> {
                  // If there's a pending key and the split key is empty,
                  // use the pending key (handles key\n=value pattern)
                  let final_key = case pending_key, string.trim(key) {
                    Some(pk), "" -> pk
                    _, _ -> key
                  }
                  let new_current = Some(#(final_key, [value]))
                  parse_lines(rest, baseline, new_acc, new_current, None, options)
                }
                // Line without '=' at entry level — buffer as pending key
                Error(_) ->
                  parse_lines(
                    rest,
                    baseline,
                    new_acc,
                    None,
                    Some(trimmed),
                    options,
                  )
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
  options: ParseOptions,
) -> List(Entry) {
  case current {
    None -> acc
    Some(#(key, value_lines)) -> {
      let value = build_value(value_lines, options)
      [Entry(key: key, value: value), ..acc]
    }
  }
}

/// Build the final value string from accumulated lines.
/// First line has leading whitespace already trimmed.
/// Trailing whitespace on the final line is trimmed.
///
/// Tab handling depends on options:
/// - `TabsAsWhitespace`: tabs in indentation are structural, stripped;
///   remaining tabs in content are replaced with spaces
/// - `TabsAsContent`: tabs are preserved as-is
fn build_value(lines: List(String), options: ParseOptions) -> String {
  let result = case lines {
    [] -> ""
    [single] -> trim_trailing(single)
    [first, ..rest] -> {
      let processed = case options.tab_handling {
        TabsAsWhitespace -> {
          // Strip tab-based indentation from continuation lines
          [first, ..list.map(rest, strip_tab_indentation)]
        }
        TabsAsContent -> {
          // Preserve tabs as content
          [first, ..rest]
        }
      }
      let joined = string.join(processed, "\n")
      trim_trailing(joined)
    }
  }
  case options.tab_handling {
    TabsAsWhitespace -> normalize_tabs(result)
    TabsAsContent -> result
  }
}

/// Strip leading whitespace from a continuation line if it contains tabs.
/// Lines with tab-based indentation have ALL leading whitespace stripped
/// (the tabs were structural indentation, not content).
/// Lines with space-only indentation are preserved as-is.
fn strip_tab_indentation(line: String) -> String {
  case has_leading_tab(line) {
    True -> strip_all_leading_whitespace(line)
    False -> line
  }
}

/// Check if a line has any tab characters in its leading whitespace.
fn has_leading_tab(line: String) -> Bool {
  has_leading_tab_chars(string.to_graphemes(line))
}

fn has_leading_tab_chars(chars: List(String)) -> Bool {
  case chars {
    ["\t", ..] -> True
    [" ", ..rest] -> has_leading_tab_chars(rest)
    _ -> False
  }
}

/// Strip all leading whitespace (tabs and spaces) from a string.
fn strip_all_leading_whitespace(s: String) -> String {
  case string.first(s) {
    Ok(" ") -> strip_all_leading_whitespace(string.drop_start(s, 1))
    Ok("\t") -> strip_all_leading_whitespace(string.drop_start(s, 1))
    _ -> s
  }
}

/// Split a line on `=` using the configured delimiter strategy.
/// Tab handling affects value trimming: when `tabs_as_content`, only spaces
/// are stripped after `=`; tabs are preserved as content.
fn split_on_equals_with(
  line: String,
  options: ParseOptions,
) -> Result(#(String, String), Nil) {
  let trim_value = case options.tab_handling {
    TabsAsContent -> trim_leading_spaces_only
    _ -> trim_leading_whitespace
  }
  case options.delimiter_strategy {
    DelimiterPreferSpaced -> split_on_spaced_equals(line, trim_value)
    _ -> split_on_first_equals(line, trim_value)
  }
}

/// Split a line on the first `=` character.
/// Returns (trimmed_key, trimmed_first_line_value).
fn split_on_first_equals(
  line: String,
  trim_value: fn(String) -> String,
) -> Result(#(String, String), Nil) {
  case string.split_once(line, "=") {
    Ok(#(raw_key, raw_value)) -> {
      let key = trim_key(raw_key)
      let value = trim_value(raw_value)
      Ok(#(key, value))
    }
    Error(_) -> Error(Nil)
  }
}

/// Split a line preferring ` = ` (space-equals-space) as delimiter.
/// Falls back to ` =` at end of line, then to first `=`.
fn split_on_spaced_equals(
  line: String,
  trim_value: fn(String) -> String,
) -> Result(#(String, String), Nil) {
  // Try " = " first (space-equals-space)
  case string.split_once(line, " = ") {
    Ok(#(raw_key, raw_value)) -> {
      let key = trim_key(raw_key)
      let value = trim_value(raw_value)
      Ok(#(key, value))
    }
    Error(_) -> {
      // Try " =" at end of line (space-equals with empty value)
      case string.ends_with(string.trim_end(line), " =") {
        True -> {
          let trimmed = string.trim_end(line)
          let raw_key = string.drop_end(trimmed, 2)
          let key = trim_key(raw_key)
          Ok(#(key, ""))
        }
        // Fall back to first `=`
        False -> split_on_first_equals(line, trim_value)
      }
    }
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

/// Trim only leading spaces (not tabs) from a string.
/// Used when `tabs_as_content` — tabs after `=` are content, not whitespace.
fn trim_leading_spaces_only(s: String) -> String {
  case string.first(s) {
    Ok(" ") -> trim_leading_spaces_only(string.drop_start(s, 1))
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
