/// CCL Parser — indentation-aware entry parsing.
///
/// Implements the CCL parsing algorithm from the docs:
/// 1. Find first `=` on a line to split key from value
/// 2. Track indentation to detect continuation lines (indent > baseline N)
/// 3. Two parsing contexts:
///    - Top-level (`parse`): N = 0 (`toplevel_indent_strip` behaviour)
///    - Nested (`parse_value`): N = first content line's indentation
///
/// Behaviours implemented:
/// - `toplevel_indent_strip`: top-level baseline is always 0
/// - `crlf_normalize_to_lf`: normalize \r\n to \n before parsing
/// - `tabs_as_whitespace`: both spaces and tabs count as whitespace
import ccl/types.{
  type Entry, type ParseOptions, DelimiterPreferSpaced, Entry, IndentPreserve,
  IndentStrip, NormalizeToLf, TabsAsContent, TabsAsWhitespace,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
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
/// When `tabs_as_content`, strips the minimum space-only indent from
/// continuation lines in each entry's value, since the structural
/// indentation (spaces) should be removed while preserving tab content.
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
  let parsed = parse_with_baseline(normalized, baseline, options)
  case options.tab_handling {
    TabsAsContent -> result.map(parsed, strip_entries_continuation_indent)
    _ -> parsed
  }
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
  case string.starts_with(text, "\r\n") {
    // Nested context with CRLF: skip \r\n, detect baseline from rest
    // Note: \r\n is a single grapheme cluster in Erlang/Gleam,
    // so drop_start(1) skips the entire \r\n sequence
    True -> {
      let rest = string.drop_start(text, 1)
      let baseline = detect_baseline(rest)
      parse_with_baseline(rest, baseline, options)
    }
    False ->
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
/// `pending_key`: buffered text from a line without `=`, used only when the
/// next non-empty line starts with `=` (empty key after split) — handles the
/// `key\n=value` pattern. Otherwise, a line without `=` becomes an entry
/// with that line as key and an empty value.
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
      let acc1 = flush_entry(acc, current, options)
      let acc2 = flush_pending_key(acc1, pending_key)
      Ok(list.reverse(acc2))
    }
    [line, ..rest] -> {
      let indent = count_leading_whitespace(line)
      let trimmed = string.trim(line)

      case trimmed {
        // Empty line: preserve within continuations, skip otherwise
        "" -> {
          case current {
            Some(#(key, value_lines)) -> {
              case has_continuation_after(rest, baseline) {
                True -> {
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
                  let new_acc = flush_entry(acc, current, options)
                  parse_lines(
                    rest,
                    baseline,
                    new_acc,
                    None,
                    pending_key,
                    options,
                  )
                }
              }
            }
            None -> parse_lines(rest, baseline, acc, None, pending_key, options)
          }
        }
        _ -> {
          case indent > baseline, current, pending_key {
            // Continuation line: append to current entry's value
            True, Some(#(key, value_lines)), _ -> {
              let new_current = Some(#(key, list.append(value_lines, [line])))
              parse_lines(rest, baseline, acc, new_current, None, options)
            }
            // Continuation line, no current, pending_key exists.
            //
            // `multiline_keys`: if the continuation has `=` with an empty key,
            // combine with pending_key to form the entry. If it has no `=`,
            // append its trimmed text to pending_key (joined by a space) so
            // multi-line keys accumulate before the `=` line arrives.
            //
            // Otherwise (a continuation with `=` and a non-empty key) fall back
            // to the legacy nesting behaviour: pending_key becomes an entry key
            // whose value is this indented block, so hierarchy recursion can
            // reparse it.
            True, None, Some(pk) -> {
              case split_on_equals_with(line, options) {
                Ok(#(key, value)) ->
                  case string.trim(key) {
                    "" -> {
                      let new_current = Some(#(pk, [value]))
                      parse_lines(
                        rest,
                        baseline,
                        acc,
                        new_current,
                        None,
                        options,
                      )
                    }
                    _ -> {
                      let new_current = Some(#(pk, ["", line]))
                      parse_lines(
                        rest,
                        baseline,
                        acc,
                        new_current,
                        None,
                        options,
                      )
                    }
                  }
                Error(_) -> {
                  let combined = pk <> " " <> trimmed
                  parse_lines(
                    rest,
                    baseline,
                    acc,
                    None,
                    Some(combined),
                    options,
                  )
                }
              }
            }
            // Continuation line, no current, no pending_key
            True, None, None -> {
              case split_on_equals_with(line, options) {
                Ok(#(key, value)) -> {
                  let new_current = Some(#(key, [value]))
                  parse_lines(rest, baseline, acc, new_current, None, options)
                }
                // No `=`: buffer as pending_key so it can combine with a
                // later `=value` line.
                Error(_) ->
                  parse_lines(rest, baseline, acc, None, Some(trimmed), options)
              }
            }
            // New entry (indent <= baseline): flush current, start new
            False, _, _ -> {
              let acc1 = flush_entry(acc, current, options)
              case split_on_equals_with(line, options) {
                Ok(#(key, value)) -> {
                  case pending_key, string.trim(key) {
                    // pending_key + line starting with `=`: combine
                    Some(pk), "" -> {
                      let new_current = Some(#(pk, [value]))
                      parse_lines(
                        rest,
                        baseline,
                        acc1,
                        new_current,
                        None,
                        options,
                      )
                    }
                    // Otherwise flush pending_key, start fresh entry
                    _, _ -> {
                      let acc2 = flush_pending_key(acc1, pending_key)
                      let new_current = Some(#(key, [value]))
                      parse_lines(
                        rest,
                        baseline,
                        acc2,
                        new_current,
                        None,
                        options,
                      )
                    }
                  }
                }
                // Line without '=' — flush any prior pending_key, buffer this
                Error(_) -> {
                  let acc2 = flush_pending_key(acc1, pending_key)
                  parse_lines(
                    rest,
                    baseline,
                    acc2,
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
}

/// Flush a pending key (line without `=`) as an entry with empty value.
fn flush_pending_key(
  acc: List(Entry),
  pending_key: Option(String),
) -> List(Entry) {
  case pending_key {
    None -> acc
    Some(key) -> [Entry(key: key, value: ""), ..acc]
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
          // Preserve tabs as content — no stripping in build_value.
          // Continuation indent stripping for tabs_as_content is handled
          // at a higher level (parse_indented_with) since parse() should
          // preserve raw continuation indentation.
          [first, ..rest]
        }
      }
      let joined = string.join(processed, "\n")
      trim_trailing(joined)
    }
  }
  result
}

/// Map each leading tab on a continuation line to a single space (OCaml-canonical
/// `continuation_tab_to_space`). Leading spaces pass through unchanged. Stops at
/// the first non-whitespace character.
fn strip_tab_indentation(line: String) -> String {
  let #(mapped, rest) =
    map_leading_tabs_to_spaces(string.to_graphemes(line), "")
  mapped <> rest
}

fn map_leading_tabs_to_spaces(
  chars: List(String),
  acc: String,
) -> #(String, String) {
  case chars {
    ["\t", ..rest] -> map_leading_tabs_to_spaces(rest, acc <> " ")
    [" ", ..rest] -> map_leading_tabs_to_spaces(rest, acc <> " ")
    _ -> #(acc, string.concat(chars))
  }
}

/// Strip the minimum space-only indent from continuation lines in each entry.
/// For multi-line values (containing \n), the continuation part (after the first
/// line) has its minimum leading-spaces-only indent removed. This removes
/// structural indentation while preserving tab content.
fn strip_entries_continuation_indent(entries: List(Entry)) -> List(Entry) {
  list.map(entries, fn(entry) {
    case string.split_once(entry.value, "\n") {
      Ok(#(first, rest)) -> {
        let rest_lines = string.split(rest, "\n")
        let min_indent = min_leading_spaces(rest_lines)
        case min_indent > 0 {
          True -> {
            let stripped_lines =
              list.map(rest_lines, fn(l) {
                strip_n_leading_spaces(l, min_indent)
              })
            Entry(
              key: entry.key,
              value: first <> "\n" <> string.join(stripped_lines, "\n"),
            )
          }
          False -> entry
        }
      }
      Error(_) -> entry
    }
  })
}

/// Count only leading space characters (not tabs) in a string.
fn count_leading_spaces(line: String) -> Int {
  count_space_chars(string.to_graphemes(line), 0)
}

fn count_space_chars(chars: List(String), count: Int) -> Int {
  case chars {
    [" ", ..rest_chars] -> count_space_chars(rest_chars, count + 1)
    _ -> count
  }
}

/// Find the minimum number of leading spaces across non-empty lines.
fn min_leading_spaces(lines: List(String)) -> Int {
  lines
  |> list.filter(fn(line) { string.trim(line) != "" })
  |> list.map(count_leading_spaces)
  |> list.reduce(int.min)
  |> result.unwrap(0)
}

/// Strip exactly n leading spaces from a string, stopping at non-space chars.
fn strip_n_leading_spaces(line: String, n: Int) -> String {
  case n > 0 {
    False -> line
    True ->
      case string.first(line) {
        Ok(" ") -> strip_n_leading_spaces(string.drop_start(line, 1), n - 1)
        _ -> line
      }
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
/// Per `tabs_as_whitespace` behaviour: both count.
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
/// Per `crlf_normalize_to_lf` behaviour.
fn normalize_line_endings(text: String) -> String {
  string.replace(text, "\r\n", "\n")
}
