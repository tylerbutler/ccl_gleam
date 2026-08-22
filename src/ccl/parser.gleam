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

/// Parse indented CCL text with an auto-detected baseline indentation.
/// `parse` uses N=0; this function detects the baseline from the first
/// content line's indentation, so pre-indented text parses correctly.
/// Under `tabs_as_content`, this strips the minimum space-only indent from
/// continuation lines in each entry's value: the structural indentation
/// (spaces) goes away, and tab content stays.
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

/// Whether a raw entry value is structurally nested CCL — a multiline value
/// containing at least one `=` — rather than a terminal leaf string.
/// Both `hierarchy.gleam` and `model/nested_parser.gleam` use this, so the
/// two projections agree on what counts as nested.
pub fn is_nested_value(raw_value: String) -> Bool {
  {
    string.starts_with(raw_value, "\n") || string.starts_with(raw_value, "\r\n")
  }
  && string.contains(raw_value, "=")
}

/// Parse a nested value (build_hierarchy calls this during recursive parsing).
/// If the text starts with `\n`, this detects the baseline from the first
/// content line's indentation. Otherwise it parses the text as a single-line
/// value. Matches OCaml's `parse_value` / `nested_kvs_p`.
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
/// `pending_key`: buffered text from lines without `=`. The parser combines
/// it with the next line that has `=`. This mirrors OCaml's
/// `many (not_char '=')`, which reads across line boundaries until it hits `=`.
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
      // Flush any remaining entry. The parser discards a trailing pending key
      // (a no-`=` line at the end of input) on purpose: with no `=` line after
      // it, the text can neither fold into a key nor form a `key = value`
      // entry. This matches the reference parser. A mid-stream pending key
      // that does not merge becomes a standalone empty-value entry (see
      // flush_pending_key).
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
            // Continuation line but no current entry: treat as a new entry.
            // This covers indented text at the start of the input.
            True, None -> {
              case split_on_equals_with(line, options) {
                Ok(#(key, value)) -> {
                  // Fold any buffered multiline-key lines into this key.
                  let merge = should_merge_pending(acc, key)
                  // A pending key that does not fold forward is its own entry
                  // (empty value), not discarded.
                  let acc = flush_pending_key(acc, pending_key, merge, options)
                  let final_key =
                    combine_key(pending_key, key, indent, baseline, merge)
                  let new_current = Some(#(final_key, [value]))
                  parse_lines(rest, baseline, acc, new_current, None, options)
                }
                // Line without '=' — accumulate into the pending key
                Error(_) -> {
                  let new_pending =
                    extend_pending(pending_key, trimmed, indent, baseline)
                  parse_lines(
                    rest,
                    baseline,
                    acc,
                    None,
                    Some(new_pending),
                    options,
                  )
                }
              }
            }
            // New entry (indent <= baseline): flush current, start new
            False, _ -> {
              let new_acc = flush_entry(acc, current, options)
              case split_on_equals_with(line, options) {
                Ok(#(key, value)) -> {
                  // Fold any buffered multiline-key lines into this key.
                  let merge = should_merge_pending(new_acc, key)
                  // A pending key that does not fold forward is its own entry
                  // (empty value), not discarded.
                  let new_acc =
                    flush_pending_key(new_acc, pending_key, merge, options)
                  let final_key =
                    combine_key(pending_key, key, indent, baseline, merge)
                  let new_current = Some(#(final_key, [value]))
                  parse_lines(
                    rest,
                    baseline,
                    new_acc,
                    new_current,
                    None,
                    options,
                  )
                }
                // Line without '=' at entry level — accumulate as pending key
                Error(_) -> {
                  let new_pending =
                    extend_pending(pending_key, trimmed, indent, baseline)
                  parse_lines(
                    rest,
                    baseline,
                    new_acc,
                    None,
                    Some(new_pending),
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

/// The separator used when a multiline-key line folds into the buffer.
/// An indented continuation line folds into a single space; an unindented
/// line keeps the literal newline. Mirrors the OCaml reference, which reads
/// every character up to `=` and trims the whole multiline key.
fn key_separator(indent: Int, baseline: Int) -> String {
  case indent > baseline {
    True -> " "
    False -> "\n"
  }
}

/// Accumulate a buffered key line (a line with no `=`) into the pending key.
fn extend_pending(
  pending: Option(String),
  trimmed_line: String,
  indent: Int,
  baseline: Int,
) -> String {
  case pending {
    None -> trimmed_line
    Some(p) -> p <> key_separator(indent, baseline) <> trimmed_line
  }
}

/// Emit a buffered pending key as a standalone empty-value entry when it does
/// not fold forward into the next `=` line's key (`merge == False`). This is
/// the non-merging half of the multiline-key rule: an unindented no-`=` line
/// after a *named*-key entry (e.g. repeated list keys) is its own entry, not
/// a prefix of the next key. When `merge == True`, `combine_key` consumes the
/// buffer, so this emits nothing.
fn flush_pending_key(
  acc: List(Entry),
  pending: Option(String),
  merge: Bool,
  options: ParseOptions,
) -> List(Entry) {
  case pending, merge {
    Some(p), False -> flush_entry(acc, Some(#(string.trim(p), [])), options)
    _, _ -> acc
  }
}

/// Decide whether a buffered pending key folds into the key part of a `=`
/// line. An empty key part always absorbs the pending buffer (the buffer *is*
/// the key, e.g. `my\n key\n= val`). A non-empty key part absorbs the pending
/// buffer only when the preceding entry has an empty key, or when there is no
/// preceding entry — the multiline-key continuation case. Otherwise the
/// pending buffer belongs to a distinct entry and must not merge forward
/// (e.g. a stray unindented line between repeated list keys).
fn should_merge_pending(acc: List(Entry), key_part: String) -> Bool {
  case string.trim(key_part) {
    "" -> True
    _ ->
      case acc {
        [] -> True
        [first, ..] -> first.key == ""
      }
  }
}

/// Combine the buffered pending key with the key part of the `=` line.
/// This trims the whole result, to match the reference's String.trim.
/// When `merge` is False, this drops the pending buffer and uses only the
/// key part.
fn combine_key(
  pending: Option(String),
  key_part: String,
  indent: Int,
  baseline: Int,
  merge: Bool,
) -> String {
  let trimmed_key = string.trim(key_part)
  case pending {
    None -> trimmed_key
    Some(p) ->
      case merge {
        False -> trimmed_key
        True ->
          case trimmed_key {
            "" -> string.trim(p)
            _ ->
              string.trim(p <> key_separator(indent, baseline) <> trimmed_key)
          }
      }
  }
}

/// Build the final value string from accumulated lines.
/// The first line already has its leading whitespace trimmed.
/// This trims trailing whitespace from the final line.
///
/// Tab handling depends on options:
/// - `TabsAsWhitespace`: tabs on the entry line's value are whitespace and
///   convert 1:1 to spaces (`tabs_as_whitespace_in_value`); LEADING tabs on
///   continuation lines are structural and also convert 1:1 to spaces
///   (`continuation_tab_to_space`).
/// - `TabsAsContent`: tabs stay unchanged
fn build_value(lines: List(String), options: ParseOptions) -> String {
  case lines {
    [] -> ""
    [single] -> trim_trailing(convert_value_tabs(single, options))
    [first, ..rest] -> {
      let processed = case options.tab_handling {
        TabsAsWhitespace -> {
          // Convert leading tab-based indentation to spaces, 1 char each
          [
            convert_value_tabs(first, options),
            ..list.map(rest, normalize_tab_indentation)
          ]
        }
        TabsAsContent -> {
          // Preserve tabs as content — no stripping in build_value.
          // `parse_indented_with` strips continuation indent for
          // tabs_as_content at a higher level, because parse() must keep
          // raw continuation indentation.
          [first, ..rest]
        }
      }
      let joined = string.join(processed, "\n")
      trim_trailing(joined)
    }
  }
}

/// Replace each tab in an entry line's value with a single space.
/// Under `tabs_as_whitespace`, a tab inside a value is whitespace and becomes
/// one space; under `tabs_as_content`, tabs stay unchanged.
fn convert_value_tabs(line: String, options: ParseOptions) -> String {
  case options.tab_handling {
    TabsAsWhitespace -> string.replace(line, "\t", " ")
    TabsAsContent -> line
  }
}

/// Convert a continuation line's leading whitespace (tabs and spaces) to an
/// equal number of spaces, 1:1 per character (`continuation_tab_to_space`).
/// This normalizes structural indentation to spaces and keeps the column
/// count; content after the leading whitespace does not change.
fn normalize_tab_indentation(line: String) -> String {
  let #(count, rest) = count_and_drop_leading_whitespace(line, 0)
  string.repeat(" ", count) <> rest
}

fn count_and_drop_leading_whitespace(
  line: String,
  count: Int,
) -> #(Int, String) {
  case string.first(line) {
    Ok(" ") ->
      count_and_drop_leading_whitespace(string.drop_start(line, 1), count + 1)
    Ok("\t") ->
      count_and_drop_leading_whitespace(string.drop_start(line, 1), count + 1)
    _ -> #(count, line)
  }
}

/// Strip the minimum space-only indent from continuation lines in each entry.
/// For a multi-line value (one that contains `\n`), this removes the minimum
/// leading-spaces-only indent from the lines after the first. The structural
/// indentation goes away; tab content stays.
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

/// Strip exactly n leading spaces from a string; stop at the first non-space
/// character.
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
/// Tab handling affects value trimming: under `tabs_as_content`, this strips
/// only spaces after `=` and keeps tabs as content.
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
      // Trim all whitespace from keys (including newlines), per the docs.
      let key = string.trim(raw_key)
      let value = trim_value(raw_value)
      Ok(#(key, value))
    }
    Error(_) -> Error(Nil)
  }
}

/// Split a line on a spaced ` =` (space-then-equals) delimiter when possible.
/// A spaced delimiter requires only a leading space. A trailing space is not
/// required, so an empty value at the end of a line (`a=b =`) still splits on
/// the spaced `=`. When no spaced delimiter exists, this splits on the first
/// bare `=`.
fn split_on_spaced_equals(
  line: String,
  trim_value: fn(String) -> String,
) -> Result(#(String, String), Nil) {
  // Try " =" first (space before equals)
  case string.split_once(line, " =") {
    Ok(#(raw_key, raw_value)) -> {
      let key = string.trim(raw_key)
      let value = trim_value(raw_value)
      Ok(#(key, value))
    }
    // No spaced delimiter: fall back to first `=`
    Error(_) -> split_on_first_equals(line, trim_value)
  }
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
/// The nested parsing context uses this, as do callers (e.g.
/// `canonical_format`) that need the top-level indent
/// `toplevel_indent_preserve` keeps.
pub fn detect_baseline(text: String) -> Int {
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

/// Check if any line after the current position has indent > baseline. If
/// one does, more continuation content follows the empty line.
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
