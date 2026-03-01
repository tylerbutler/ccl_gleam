/// CCL Hierarchy Builder — recursive fixed-point object construction.
///
/// Converts flat entries from the parser into nested CCL structure.
/// The algorithm: for each entry, if the value contains `=`, recursively
/// parse it and build hierarchy from the result. Stop when values have
/// no more `=` characters (fixed point).
///
/// This follows the docs' Implementing CCL page and mirrors OCaml's
/// `Model.fix` function, but uses a tagged union instead of uniform `Fix` type.
import ccl/parser
import ccl/types.{
  type BuildOptions, type CCL, type CCLValue, type Entry, type ParseOptions,
  CclList, CclObject, CclString, LexicographicOrder,
}
import gleam/dict
import gleam/list
import gleam/string

/// Build nested CCL structure from flat entries via recursive parsing.
/// Uses default options (insertion order, default parse options).
///
/// For each entry:
/// - If value contains `=` → parse recursively, build hierarchy (recurse)
/// - If value has no `=` → terminal string (fixed point reached)
/// - If key is `""` → accumulate as list item
pub fn build_hierarchy(entries: List(Entry)) -> CCL {
  build_hierarchy_with(
    entries,
    types.default_build_options(),
    types.default_parse_options(),
  )
}

/// Build nested CCL structure with configurable options.
pub fn build_hierarchy_with(
  entries: List(Entry),
  build_options: BuildOptions,
  parse_options: ParseOptions,
) -> CCL {
  build_entries(entries, dict.new(), build_options, parse_options)
}

/// Process entries into a CCL dict, accumulating values for duplicate keys.
fn build_entries(
  entries: List(Entry),
  acc: CCL,
  build_options: BuildOptions,
  parse_options: ParseOptions,
) -> CCL {
  case entries {
    [] -> acc
    [entry, ..rest] -> {
      let value = resolve_value(entry.value, build_options, parse_options)
      let new_acc = insert_value(acc, entry.key, value, build_options)
      build_entries(rest, new_acc, build_options, parse_options)
    }
  }
}

/// Resolve a raw value string into a CCLValue.
/// Only multi-line values (starting with `\n`) represent nested structure
/// that should be recursively parsed. Single-line values are always terminal
/// strings, even if they contain `=` — that `=` is content, not a delimiter.
fn resolve_value(
  raw_value: String,
  build_options: BuildOptions,
  parse_options: ParseOptions,
) -> CCLValue {
  case string.starts_with(raw_value, "\n"), string.contains(raw_value, "=") {
    // Multi-line value with `=` → nested structure, recurse
    True, True -> {
      case parser.parse_value_with(raw_value, parse_options) {
        Ok(nested_entries) -> {
          case nested_entries {
            // Parsing succeeded but yielded nothing — treat as string
            [] -> CclString(raw_value)
            // Got nested entries — build hierarchy recursively
            _ ->
              CclObject(build_hierarchy_with(
                nested_entries,
                build_options,
                parse_options,
              ))
          }
        }
        // Parse failed — treat value as plain string
        Error(_) -> CclString(raw_value)
      }
    }
    // Single-line or no `=` → terminal string (fixed point)
    _, _ -> CclString(raw_value)
  }
}

/// Insert a value into the CCL dict, handling duplicate keys and list accumulation.
fn insert_value(
  acc: CCL,
  key: String,
  value: CCLValue,
  build_options: BuildOptions,
) -> CCL {
  case key {
    // Empty key → list item
    "" -> {
      case dict.get(acc, "") {
        // First list item — start a new list
        Error(_) -> dict.insert(acc, "", CclList([value]))
        // Append to existing list
        Ok(CclList(existing)) -> {
          let new_list = list.append(existing, [value])
          let sorted = case build_options.array_order {
            LexicographicOrder -> sort_ccl_values(new_list)
            _ -> new_list
          }
          dict.insert(acc, "", CclList(sorted))
        }
        // Existing non-list value with empty key — wrap both in list
        Ok(existing) -> {
          let new_list = [existing, value]
          let sorted = case build_options.array_order {
            LexicographicOrder -> sort_ccl_values(new_list)
            _ -> new_list
          }
          dict.insert(acc, "", CclList(sorted))
        }
      }
    }
    // Named key
    _ -> {
      case dict.get(acc, key) {
        // First occurrence — just insert
        Error(_) -> dict.insert(acc, key, value)
        // Duplicate key — merge
        Ok(existing) ->
          dict.insert(
            acc,
            key,
            merge_values(existing, value, build_options),
          )
      }
    }
  }
}

/// Sort CCL values lexicographically by their string representation.
fn sort_ccl_values(values: List(CCLValue)) -> List(CCLValue) {
  list.sort(values, fn(a, b) { string.compare(ccl_value_key(a), ccl_value_key(b)) })
}

/// Get a sort key for a CCL value.
fn ccl_value_key(value: CCLValue) -> String {
  case value {
    CclString(s) -> s
    CclObject(_) -> ""
    CclList(_) -> ""
  }
}

/// Merge two values for the same key.
/// Two objects merge recursively. Otherwise, accumulate into a list.
/// Empty-string values are filtered from duplicate-key lists.
/// Lexicographic sorting is applied when configured.
fn merge_values(
  existing: CCLValue,
  new: CCLValue,
  build_options: BuildOptions,
) -> CCLValue {
  case existing, new {
    // Two objects: merge their dicts
    CclObject(a), CclObject(b) -> CclObject(merge_dicts(a, b, build_options))
    // Existing list: append new value
    CclList(items), _ -> {
      let new_list =
        list.append(items, [new])
        |> filter_empty_strings
      let sorted = case build_options.array_order {
        LexicographicOrder -> sort_ccl_values(new_list)
        _ -> new_list
      }
      CclList(sorted)
    }
    // Convert to list
    _, _ -> {
      let new_list =
        [existing, new]
        |> filter_empty_strings
      let sorted = case build_options.array_order {
        LexicographicOrder -> sort_ccl_values(new_list)
        _ -> new_list
      }
      CclList(sorted)
    }
  }
}

/// Filter out empty-string values from a list.
/// Duplicate named keys with empty values (e.g. `key =`) are excluded.
fn filter_empty_strings(values: List(CCLValue)) -> List(CCLValue) {
  list.filter(values, fn(v) {
    case v {
      CclString("") -> False
      _ -> True
    }
  })
}

/// Merge two CCL dicts, recursively merging values for shared keys.
fn merge_dicts(a: CCL, b: CCL, build_options: BuildOptions) -> CCL {
  dict.fold(b, a, fn(acc, key, b_value) {
    case dict.get(acc, key) {
      Error(_) -> dict.insert(acc, key, b_value)
      Ok(a_value) ->
        dict.insert(acc, key, merge_values(a_value, b_value, build_options))
    }
  })
}
