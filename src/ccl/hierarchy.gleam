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
  type CCL, type CCLValue, type Entry, CclList, CclObject, CclString,
}
import gleam/dict
import gleam/list
import gleam/string

/// Build nested CCL structure from flat entries via recursive parsing.
///
/// For each entry:
/// - If value contains `=` → parse recursively, build hierarchy (recurse)
/// - If value has no `=` → terminal string (fixed point reached)
/// - If key is `""` → accumulate as list item
pub fn build_hierarchy(entries: List(Entry)) -> CCL {
  build_entries(entries, dict.new())
}

/// Process entries into a CCL dict, accumulating values for duplicate keys.
fn build_entries(entries: List(Entry), acc: CCL) -> CCL {
  case entries {
    [] -> acc
    [entry, ..rest] -> {
      let value = resolve_value(entry.value)
      let new_acc = insert_value(acc, entry.key, value)
      build_entries(rest, new_acc)
    }
  }
}

/// Resolve a raw value string into a CCLValue.
/// If the value contains `=`, try to parse it recursively (fixed-point step).
/// Otherwise it's a terminal string.
fn resolve_value(raw_value: String) -> CCLValue {
  case string.contains(raw_value, "=") {
    True -> {
      // Try recursive parsing
      case parser.parse_value(raw_value) {
        Ok(nested_entries) -> {
          case nested_entries {
            // Parsing succeeded but yielded nothing — treat as string
            [] -> CclString(raw_value)
            // Got nested entries — build hierarchy recursively
            _ -> CclObject(build_hierarchy(nested_entries))
          }
        }
        // Parse failed — treat value as plain string
        Error(_) -> CclString(raw_value)
      }
    }
    // No `=` → terminal string (fixed point)
    False -> CclString(raw_value)
  }
}

/// Insert a value into the CCL dict, handling duplicate keys and list accumulation.
fn insert_value(acc: CCL, key: String, value: CCLValue) -> CCL {
  case key {
    // Empty key → list item
    "" -> {
      case dict.get(acc, "") {
        // First list item — start a new list
        Error(_) -> dict.insert(acc, "", CclList([value]))
        // Append to existing list
        Ok(CclList(existing)) ->
          dict.insert(acc, "", CclList(list.append(existing, [value])))
        // Existing non-list value with empty key — wrap both in list
        Ok(existing) -> dict.insert(acc, "", CclList([existing, value]))
      }
    }
    // Named key
    _ -> {
      case dict.get(acc, key) {
        // First occurrence — just insert
        Error(_) -> dict.insert(acc, key, value)
        // Duplicate key — merge
        Ok(existing) -> dict.insert(acc, key, merge_values(existing, value))
      }
    }
  }
}

/// Merge two values for the same key.
/// Two objects merge recursively. Otherwise, accumulate into a list.
fn merge_values(existing: CCLValue, new: CCLValue) -> CCLValue {
  case existing, new {
    // Two objects: merge their dicts
    CclObject(a), CclObject(b) -> CclObject(merge_dicts(a, b))
    // Existing list: append new value
    CclList(items), _ -> CclList(list.append(items, [new]))
    // Convert to list
    _, _ -> CclList([existing, new])
  }
}

/// Merge two CCL dicts, recursively merging values for shared keys.
fn merge_dicts(a: CCL, b: CCL) -> CCL {
  dict.fold(b, a, fn(acc, key, b_value) {
    case dict.get(acc, key) {
      Error(_) -> dict.insert(acc, key, b_value)
      Ok(a_value) -> dict.insert(acc, key, merge_values(a_value, b_value))
    }
  })
}
