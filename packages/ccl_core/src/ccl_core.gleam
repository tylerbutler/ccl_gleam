import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// === CORE DATA TYPES ===

pub type Entry {
  Entry(key: String, value: String)
}

pub type ParseError {
  ParseError(line: Int, reason: String)
}

// === NESTED CCL DATA STRUCTURE ===

/// Recursive CCL structure equivalent to OCaml's `type t = Fix of t Map.t`
/// This represents the nested object structure after applying the fixpoint algorithm
pub type CCL {
  CCL(map: dict.Dict(String, CCL))
}

/// Value entry type for intermediate processing during object construction
pub type ValueEntry {
  StringValue(String)
  NestedCCL(dict.Dict(String, List(ValueEntry)))
}

// === CORE PUBLIC API ===

/// Parse CCL text into a list of key-value entries
pub fn parse(text: String) -> Result(List(Entry), ParseError) {
  let input =
    text
    |> string.replace("\r\n", "\n")
    |> string.replace("\r", "\n")

  // Handle truly empty input
  case string.length(string.trim(text)) == 0 && string.length(text) == 0 {
    True -> Ok([])
    False -> {
      // Handle whitespace-only input as error
      case string.length(string.trim(text)) == 0 {
        True -> Error(ParseError(1, "Input contains only whitespace"))
        False -> parse_with_indentation(string.split(input, "\n"))
      }
    }
  }
}

/// Convert flat key-value pairs into nested CCL structure using fixpoint algorithm
pub fn make_objects(entries: List(Entry)) -> CCL {
  // Group entries by key, allowing multiple values per key
  let grouped = group_entries_by_key(entries, dict.new())

  // Convert to value entries and apply fixpoint algorithm
  let value_entries =
    dict.map_values(grouped, fn(_key, values) {
      convert_to_value_entries(values)
    })

  // Apply fixpoint until convergence
  fix_value_entries(value_entries)
}

/// Get a value from CCL using a dot-separated path
pub fn get_value(ccl: CCL, path: String) -> Result(String, String) {
  let keys = string.split(path, ".")
  get_value_by_keys(ccl, keys)
}

/// Get all values for a key (useful for list-style structures with empty keys)
pub fn get_values(ccl: CCL, path: String) -> List(String) {
  let keys = string.split(path, ".")
  case get_ccl_by_keys(ccl, keys) {
    Ok(target_ccl) -> get_all_terminal_values(target_ccl)
    Error(_) -> []
  }
}

/// Get nested CCL object at a specific path
pub fn get_nested(ccl: CCL, path: String) -> Result(CCL, String) {
  let keys = string.split(path, ".")
  get_ccl_by_keys(ccl, keys)
}

/// Check if a path exists in the CCL structure
pub fn has_key(ccl: CCL, path: String) -> Bool {
  case get_value(ccl, path) {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Get all keys at a specific path level
pub fn get_keys(ccl: CCL, path: String) -> List(String) {
  let target_ccl = case path {
    "" -> Ok(ccl)
    // Top level
    _ -> get_nested(ccl, path)
  }

  case target_ccl {
    Ok(CCL(map)) ->
      dict.keys(map)
      |> list.filter(fn(key) { key != "" })
    // Filter out empty keys used for terminal values
    Error(_) -> []
  }
}

/// Create an empty CCL structure
pub fn empty_ccl() -> CCL {
  CCL(dict.new())
}

// === HELPER FUNCTIONS ===

/// Get a value using a list of keys
pub fn get_value_by_keys(ccl: CCL, keys: List(String)) -> Result(String, String) {
  case keys {
    [] -> Error("Empty path")
    [single_key] -> get_terminal_value(ccl, single_key)
    [first_key, ..rest_keys] -> {
      case get_nested_ccl(ccl, first_key) {
        Ok(nested_ccl) -> get_value_by_keys(nested_ccl, rest_keys)
        Error(err) -> Error(err)
      }
    }
  }
}

/// Create a CCL with a single key-value pair
pub fn single_key_val(key: String, value: String) -> CCL {
  let leaf_dict = dict.from_list([#(value, empty_ccl())])
  let leaf_ccl = CCL(leaf_dict)
  let outer_dict = dict.from_list([#(key, leaf_ccl)])
  CCL(outer_dict)
}

/// Merge two CCL structures recursively
pub fn merge_ccl(ccl1: CCL, ccl2: CCL) -> CCL {
  case ccl1, ccl2 {
    CCL(map1), CCL(map2) -> {
      let merged_map =
        dict.fold(map2, map1, fn(acc, key, value2) {
          case dict.get(acc, key) {
            Ok(value1) -> dict.insert(acc, key, merge_ccl(value1, value2))
            Error(_) -> dict.insert(acc, key, value2)
          }
        })
      CCL(merged_map)
    }
  }
}

/// Create CCL from a list of CCL structures
pub fn ccl_from_list(ccls: List(CCL)) -> CCL {
  list.fold(ccls, empty_ccl(), merge_ccl)
}

// === INTERNAL FUNCTIONS ===

fn get_nested_ccl(ccl: CCL, key: String) -> Result(CCL, String) {
  case ccl {
    CCL(map) -> {
      case dict.get(map, key) {
        Ok(nested_ccl) -> Ok(nested_ccl)
        Error(_) -> Error("Key '" <> key <> "' not found")
      }
    }
  }
}

fn get_terminal_value(ccl: CCL, key: String) -> Result(String, String) {
  case get_nested_ccl(ccl, key) {
    Ok(CCL(inner_map)) -> {
      // Look for the empty key ("") which contains terminal values
      case dict.get(inner_map, "") {
        Ok(CCL(terminal_map)) -> {
          // Get the first terminal value (keys that map to empty CCL)
          let terminal_values =
            dict.to_list(terminal_map)
            |> list.filter(fn(pair) {
              let #(_, CCL(value_map)) = pair
              dict.size(value_map) == 0
            })
            |> list.map(fn(pair) { pair.0 })

          case terminal_values {
            [single_value] -> Ok(single_value)
            [] -> Error("No terminal value found for key '" <> key <> "'")
            [first_value, ..] -> Ok(first_value)
            // Return first value if multiple
          }
        }
        Error(_) ->
          Error(
            "Key '" <> key <> "' has no terminal value (empty key not found)",
          )
      }
    }
    Error(err) -> Error(err)
  }
}

fn get_all_terminal_values(ccl: CCL) -> List(String) {
  get_all_terminal_values_recursive(ccl)
}

fn get_all_terminal_values_recursive(ccl: CCL) -> List(String) {
  case ccl {
    CCL(map) -> {
      dict.to_list(map)
      |> list.flat_map(fn(pair) {
        let #(key, CCL(inner_map)) = pair
        case dict.size(inner_map) == 0 {
          True -> [key]
          // Terminal value found
          False -> get_all_terminal_values_recursive(CCL(inner_map))
          // Keep searching deeper
        }
      })
    }
  }
}

pub fn get_ccl_by_keys(ccl: CCL, keys: List(String)) -> Result(CCL, String) {
  case keys {
    [] -> Ok(ccl)
    [first_key, ..rest_keys] -> {
      case get_nested_ccl(ccl, first_key) {
        Ok(nested_ccl) -> get_ccl_by_keys(nested_ccl, rest_keys)
        Error(err) -> Error(err)
      }
    }
  }
}

// === PARSING IMPLEMENTATION ===

fn parse_with_indentation(
  lines: List(String),
) -> Result(List(Entry), ParseError) {
  case find_first_key_line(lines, 1) {
    Error(err) -> Error(err)
    Ok(#(first_line, _)) -> {
      let base_indent = count_leading_spaces(first_line)
      parse_lines_with_base_indent(lines, base_indent, 1, None, [])
    }
  }
}

fn find_first_key_line(
  lines: List(String),
  line_no: Int,
) -> Result(#(String, Int), ParseError) {
  case lines {
    [] -> Error(ParseError(line_no, "No key-value pairs found"))
    [line, ..rest] -> {
      case is_empty_line(line) {
        True -> find_first_key_line(rest, line_no + 1)
        False ->
          case string.contains(line, "=") {
            True -> Ok(#(line, line_no))
            False -> {
              // Check if the next non-empty line starts with "="
              case find_equals_line(rest) {
                True -> Ok(#(line, line_no))
                False ->
                  Error(ParseError(
                    line_no,
                    "First non-empty line must contain a key-value pair with '='",
                  ))
              }
            }
          }
      }
    }
  }
}

fn find_equals_line(lines: List(String)) -> Bool {
  case lines {
    [] -> False
    [line, ..rest] -> {
      case is_empty_line(line) {
        True -> find_equals_line(rest)
        False -> string.starts_with(string.trim(line), "=")
      }
    }
  }
}

fn find_and_consume_equals_line(
  lines: List(String),
) -> Result(#(String, List(String)), Nil) {
  find_and_consume_equals_line_helper(lines, [])
}

fn find_and_consume_equals_line_helper(
  lines: List(String),
  skipped: List(String),
) -> Result(#(String, List(String)), Nil) {
  case lines {
    [] -> Error(Nil)
    [line, ..rest] -> {
      case is_empty_line(line) {
        True -> find_and_consume_equals_line_helper(rest, [line, ..skipped])
        False -> {
          case string.starts_with(string.trim(line), "=") {
            True -> {
              let value_part = string.drop_start(string.trim(line), 1)
              let remaining_lines = list.append(list.reverse(skipped), rest)
              Ok(#(value_part, remaining_lines))
            }
            False -> Error(Nil)
          }
        }
      }
    }
  }
}

fn parse_lines_with_base_indent(
  lines: List(String),
  base_indent: Int,
  line_no: Int,
  current: Option(#(String, List(String))),
  acc: List(Entry),
) -> Result(List(Entry), ParseError) {
  case lines {
    [] ->
      case current {
        None -> Ok(list.reverse(acc))
        Some(#(k, vlines_rev)) ->
          Ok(
            list.reverse([
              Entry(k, join_and_trim_value_lines(vlines_rev)),
              ..acc
            ]),
          )
      }
    [line, ..rest] -> {
      case is_empty_line(line) {
        True ->
          case current {
            None ->
              parse_lines_with_base_indent(
                rest,
                base_indent,
                line_no + 1,
                current,
                acc,
              )
            Some(#(k, vlines_rev)) -> {
              let vlines_rev2 = ["", ..vlines_rev]
              parse_lines_with_base_indent(
                rest,
                base_indent,
                line_no + 1,
                Some(#(k, vlines_rev2)),
                acc,
              )
            }
          }
        False -> {
          let line_indent = count_leading_spaces(line)
          case line_indent > base_indent {
            True -> {
              case current {
                None ->
                  Error(ParseError(
                    line_no,
                    "Continuation line found without preceding key-value pair",
                  ))
                Some(#(k, vlines_rev)) -> {
                  let continuation_value = rstrip_whitespace(line)
                  let vlines_rev2 = [continuation_value, ..vlines_rev]
                  parse_lines_with_base_indent(
                    rest,
                    base_indent,
                    line_no + 1,
                    Some(#(k, vlines_rev2)),
                    acc,
                  )
                }
              }
            }
            False -> {
              case string.contains(line, "=") {
                True -> {
                  let acc2 = case current {
                    None -> acc
                    Some(#(k, vlines_rev)) -> [
                      Entry(k, join_and_trim_value_lines(vlines_rev)),
                      ..acc
                    ]
                  }
                  case string.split_once(line, "=") {
                    Ok(#(key_part, value_part)) -> {
                      let key = string.trim(key_part)
                      let value_line = trim_value_line(value_part)
                      let vlines_rev = case string.length(value_line) == 0 {
                        True -> [""]
                        False -> [value_line]
                      }
                      parse_lines_with_base_indent(
                        rest,
                        base_indent,
                        line_no + 1,
                        Some(#(key, vlines_rev)),
                        acc2,
                      )
                    }
                    Error(_) ->
                      Error(ParseError(line_no, "Invalid key-value line"))
                  }
                }
                False -> {
                  case current {
                    None -> {
                      // Check if the next line starts with "=" (multi-line key case)
                      case find_and_consume_equals_line(rest) {
                        Ok(#(value_part, remaining_lines)) -> {
                          let key = string.trim(line)
                          let value_line = trim_value_line(value_part)
                          let vlines_rev = case string.length(value_line) == 0 {
                            True -> [""]
                            False -> [value_line]
                          }
                          parse_lines_with_base_indent(
                            remaining_lines,
                            base_indent,
                            line_no + 2,
                            Some(#(key, vlines_rev)),
                            acc,
                          )
                        }
                        Error(_) ->
                          Error(ParseError(
                            line_no,
                            "Non-continuation line without equals sign",
                          ))
                      }
                    }
                    Some(#(k, vlines_rev)) -> {
                      let continuation_value = rstrip_whitespace(line)
                      let vlines_rev2 = [continuation_value, ..vlines_rev]
                      parse_lines_with_base_indent(
                        rest,
                        base_indent,
                        line_no + 1,
                        Some(#(k, vlines_rev2)),
                        acc,
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
  }
}

fn is_empty_line(line: String) -> Bool {
  string.length(string.trim(line)) == 0
}

// Count leading indentation: both spaces and tabs count as 1 unit each
// This matches the OCaml reference implementation and spec v1.2.0
fn count_leading_spaces(line: String) -> Int {
  count_leading_spaces_helper(string.to_graphemes(line), 0)
}

fn count_leading_spaces_helper(graphemes: List(String), count: Int) -> Int {
  case graphemes {
    [] -> count
    [" ", ..rest] -> count_leading_spaces_helper(rest, count + 1)
    ["\t", ..rest] -> count_leading_spaces_helper(rest, count + 1)
    _ -> count
  }
}

fn trim_value_line(line: String) -> String {
  line
  |> lstrip_spaces
  |> rstrip_whitespace
}

fn lstrip_spaces(s: String) -> String {
  lstrip_while(s, fn(c) { c == " " })
}

fn rstrip_whitespace(s: String) -> String {
  rstrip_while(s, fn(c) { c == " " || c == "\t" || c == "\n" || c == "\r" })
}

fn lstrip_while(s: String, keep: fn(String) -> Bool) -> String {
  lstrip_while_helper(string.to_graphemes(s), keep)
}

fn lstrip_while_helper(gs: List(String), keep: fn(String) -> Bool) -> String {
  case gs {
    [] -> ""
    [g, ..rest] ->
      case keep(g) {
        True -> lstrip_while_helper(rest, keep)
        False -> string.join(gs, "")
      }
  }
}

fn rstrip_while(s: String, keep: fn(String) -> Bool) -> String {
  let rev = list.reverse(string.to_graphemes(s))
  let kept_rev = rstrip_while_helper(rev, keep)
  string.join(list.reverse(kept_rev), "")
}

fn rstrip_while_helper(
  gs: List(String),
  keep: fn(String) -> Bool,
) -> List(String) {
  case gs {
    [] -> []
    [g, ..rest] ->
      case keep(g) {
        True -> rstrip_while_helper(rest, keep)
        False -> gs
      }
  }
}

fn join_and_trim_value_lines(vlines_rev: List(String)) -> String {
  let vlines = list.reverse(vlines_rev)
  let out = string.join(vlines, "\n")
  out
  |> lstrip_spaces
  |> rstrip_whitespace
}

// === FIXPOINT ALGORITHM IMPLEMENTATION ===

/// Parse a value string recursively into key-value pairs
fn parse_value(text: String) -> Result(List(Entry), ParseError) {
  let input =
    text
    |> string.replace("\r\n", "\n")
    |> string.replace("\r", "\n")

  // Handle empty input
  case string.length(string.trim(text)) == 0 {
    True -> Ok([])
    False -> {
      let lines = string.split(input, "\n")
      parse_value_with_base_indent(lines)
    }
  }
}

/// Parse value lines by finding base indentation from first non-empty line
fn parse_value_with_base_indent(
  lines: List(String),
) -> Result(List(Entry), ParseError) {
  case find_first_non_empty_line(lines, 1) {
    Error(err) -> Error(err)
    Ok(#(first_line, _line_no)) -> {
      let base_indent = count_leading_spaces(first_line)
      parse_lines_with_base_indent(lines, base_indent, 1, None, [])
    }
  }
}

/// Find first non-empty line for determining base indentation
fn find_first_non_empty_line(
  lines: List(String),
  line_no: Int,
) -> Result(#(String, Int), ParseError) {
  case lines {
    [] -> Error(ParseError(line_no, "No content found"))
    [line, ..rest] -> {
      case is_empty_line(line) {
        True -> find_first_non_empty_line(rest, line_no + 1)
        False -> Ok(#(line, line_no))
      }
    }
  }
}

/// Group entries by key, collecting multiple values for the same key
fn group_entries_by_key(
  entries: List(Entry),
  acc: dict.Dict(String, List(String)),
) -> dict.Dict(String, List(String)) {
  case entries {
    [] -> acc
    [Entry(key, value), ..rest] -> {
      let updated_acc = case dict.get(acc, key) {
        Ok(existing_values) -> dict.insert(acc, key, [value, ..existing_values])
        Error(_) -> dict.insert(acc, key, [value])
      }
      group_entries_by_key(rest, updated_acc)
    }
  }
}

/// Convert string values to ValueEntry list
fn convert_to_value_entries(values: List(String)) -> List(ValueEntry) {
  list.map(values, fn(value) {
    // Try to parse the value as nested CCL
    case parse_value(value) {
      Ok(nested_entries) -> {
        case nested_entries {
          [] -> StringValue(value)
          _ -> {
            let nested_grouped =
              group_entries_by_key(nested_entries, dict.new())
            let nested_value_entries =
              dict.map_values(nested_grouped, fn(_key, values) {
                convert_to_value_entries(values)
              })
            NestedCCL(nested_value_entries)
          }
        }
      }
      Error(_) -> StringValue(value)
    }
  })
}

/// Apply fixpoint algorithm to value entries until convergence
fn fix_value_entries(entry_map: dict.Dict(String, List(ValueEntry))) -> CCL {
  // Convert value entries to CCL structure
  let ccl_map =
    dict.map_values(entry_map, fn(_key, value_entries) {
      // Combine all values for this key
      list.fold(value_entries, empty_ccl(), fn(acc, entry) {
        case entry {
          // For string values, create terminal entries with empty key
          StringValue(str) -> merge_ccl(acc, single_key_val("", str))
          // For nested structures, recursively process
          NestedCCL(nested_map) -> merge_ccl(acc, fix_value_entries(nested_map))
        }
      })
    })

  CCL(ccl_map)
}
