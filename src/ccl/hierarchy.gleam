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
/// Multi-line values (starting with `\n` or `\r\n`) represent nested
/// structure that gets recursively parsed. Single-line values are always
/// terminal strings, even if they contain `=` — that `=` is content, not a
/// delimiter.
fn resolve_value(
  raw_value: String,
  build_options: BuildOptions,
  parse_options: ParseOptions,
) -> CCLValue {
  let is_multiline =
    string.starts_with(raw_value, "\n") || string.starts_with(raw_value, "\r\n")
  case is_multiline {
    True ->
      case parser.parse_value_with(raw_value, parse_options) {
        Ok([]) -> CclString(raw_value)
        Ok(nested_entries) ->
          CclObject(build_hierarchy_with(
            nested_entries,
            build_options,
            parse_options,
          ))
        Error(_) -> CclString(raw_value)
      }
    False -> CclString(raw_value)
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
          dict.insert(acc, "", CclList(maybe_sort(new_list, build_options)))
        }
        // Existing non-list value with empty key — wrap both in list
        Ok(existing) -> {
          let new_list = [existing, value]
          dict.insert(acc, "", CclList(maybe_sort(new_list, build_options)))
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
          dict.insert(acc, key, merge_values(existing, value, build_options))
      }
    }
  }
}

/// Apply lexicographic sorting if configured, otherwise return as-is.
fn maybe_sort(
  values: List(CCLValue),
  build_options: BuildOptions,
) -> List(CCLValue) {
  case build_options.array_order {
    LexicographicOrder -> sort_ccl_values(values)
    _ -> values
  }
}

/// Sort CCL values lexicographically by their string representation.
fn sort_ccl_values(values: List(CCLValue)) -> List(CCLValue) {
  list.sort(values, fn(a, b) {
    string.compare(ccl_value_key(a), ccl_value_key(b))
  })
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
      let new_list = list.append(items, [new])
      CclList(maybe_sort(new_list, build_options))
    }
    // Convert to list
    _, _ -> {
      let new_list = [existing, new]
      CclList(maybe_sort(new_list, build_options))
    }
  }
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
