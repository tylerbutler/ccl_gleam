import ccl_core.{type CCL, type Entry}
import gleam/dict
import gleam/list
import gleam/string

// === CORE API TYPES ===

/// Unified value type returned by the main get() function
pub type CclValue {
  /// Single string value
  CclString(String)
  /// List of string values  
  CclList(List(String))
  /// Nested CCL object
  CclObject(CCL)
}

// === NODE TYPE DETECTION ===

/// Types of nodes in CCL structure
pub type NodeType {
  /// Single terminal value (leaf node)
  SingleValue
  /// List of values (multiple empty keys pointing to terminals)  
  ListValue
  /// Nested object with key-value pairs
  ObjectValue
  /// Key doesn't exist
  Missing
}

/// Determine the type of data at a given path
pub fn node_type(ccl: CCL, path: String) -> NodeType {
  let keys = string.split(path, ".")
  case ccl_core.get_ccl_by_keys(ccl, keys) {
    Ok(target_ccl) -> classify_node_type(target_ccl)
    Error(_) -> Missing
  }
}

/// Classify the type of a CCL node
fn classify_node_type(ccl: CCL) -> NodeType {
  case ccl {
    ccl_core.CCL(map) -> {
      let entries = dict.to_list(map)
      case entries {
        // Empty map = missing/invalid
        [] -> Missing
        // Single entry with empty key = check if it's a terminal value or nested structure
        [#("", inner_ccl)] -> {
          case inner_ccl {
            ccl_core.CCL(inner_map) -> {
              let inner_entries = dict.to_list(inner_map)
              case inner_entries {
                // Empty inner map = this is probably not a valid terminal
                [] -> Missing
                // Single empty key in inner map = this is a list structure
                [#("", ccl_core.CCL(_))] -> {
                  let terminal_count = list.length(get_all_terminal_values(ccl))
                  case terminal_count {
                    0 -> Missing
                    1 -> SingleValue
                    _ -> ListValue
                  }
                }
                // Multiple entries or regular keys in inner map = check if terminals
                _ -> {
                  let terminal_values = get_terminal_values_from_map(inner_map)
                  case list.length(terminal_values) {
                    0 -> Missing
                    1 -> SingleValue
                    _ -> ListValue
                  }
                }
              }
            }
          }
        }
        // Check for multiple entries or entries with empty keys
        _ -> {
          let has_empty_key = list.any(entries, fn(pair) { pair.0 == "" })
          case has_empty_key {
            True -> {
              let terminal_count = list.length(get_all_terminal_values(ccl))
              case terminal_count {
                0 -> Missing
                1 -> SingleValue
                _ -> ListValue
              }
            }
            False -> ObjectValue
          }
        }
      }
    }
  }
}

/// Get terminal values from a map structure
fn get_terminal_values_from_map(map: dict.Dict(String, CCL)) -> List(String) {
  dict.to_list(map)
  |> list.filter(fn(pair) {
    let #(_, ccl_core.CCL(inner_map)) = pair
    dict.size(inner_map) == 0
  })
  |> list.map(fn(pair) { pair.0 })
}

fn get_all_terminal_values(ccl: CCL) -> List(String) {
  get_all_terminal_values_recursive(ccl)
}

fn get_all_terminal_values_recursive(ccl: CCL) -> List(String) {
  case ccl {
    ccl_core.CCL(map) -> {
      dict.to_list(map)
      |> list.flat_map(fn(pair) {
        let #(key, ccl_core.CCL(inner_map)) = pair
        case dict.size(inner_map) == 0 {
          True -> [key]
          // Terminal value found
          False -> get_all_terminal_values_recursive(ccl_core.CCL(inner_map))
          // Keep searching deeper
        }
      })
    }
  }
}

// === CORE PUBLIC API ===

/// Main accessor function that returns values in their natural form
/// This is the primary way to access CCL data
pub fn get(ccl: CCL, path: String) -> Result(CclValue, String) {
  case node_type(ccl, path) {
    SingleValue -> {
      case ccl_core.get_value(ccl, path) {
        Ok(value) -> Ok(CclString(value))
        Error(err) -> Error(err)
      }
    }
    ListValue -> {
      let values = ccl_core.get_values(ccl, path)
      case values {
        [] -> Error("Path '" <> path <> "' contains no values.")
        _ -> Ok(CclList(values))
      }
    }
    ObjectValue -> {
      case ccl_core.get_nested(ccl, path) {
        Ok(nested_ccl) -> Ok(CclObject(nested_ccl))
        Error(err) -> Error(err)
      }
    }
    Missing -> Error("Path '" <> path <> "' not found.")
  }
}

// === SMART/CONVENIENCE FUNCTIONS ===

/// Smart value accessor that returns appropriate type based on node structure
/// - Single values return Ok(value)
/// - Lists return Error with suggestion to use get_list()
/// - Objects return Error with suggestion to use get_nested()
pub fn get_smart_value(ccl: CCL, path: String) -> Result(String, String) {
  case node_type(ccl, path) {
    SingleValue -> ccl_core.get_value(ccl, path)
    ListValue ->
      Error("Path '" <> path <> "' contains a list. Use get_list() instead.")
    ObjectValue ->
      Error(
        "Path '" <> path <> "' contains an object. Use get_nested() instead.",
      )
    Missing -> Error("Path '" <> path <> "' not found.")
  }
}

/// Get a list of values, with smart detection
/// Works for both list structures (empty keys) and single values (returns single-item list)
pub fn get_list(ccl: CCL, path: String) -> Result(List(String), String) {
  case node_type(ccl, path) {
    SingleValue | ListValue -> {
      // Use get_values for both - it handles both single and multiple values
      let values = ccl_core.get_values(ccl, path)
      case values {
        [] -> Error("Path '" <> path <> "' contains no values.")
        _ -> Ok(values)
      }
    }
    ObjectValue ->
      Error("Path '" <> path <> "' contains an object, not a list.")
    Missing -> Error("Path '" <> path <> "' not found.")
  }
}

/// Get a value with automatic list flattening for single-item lists
/// This makes it easier to work with values that might be lists
pub fn get_value_or_first(ccl: CCL, path: String) -> Result(String, String) {
  case node_type(ccl, path) {
    SingleValue | ListValue -> {
      case ccl_core.get_values(ccl, path) {
        [] -> Error("Path '" <> path <> "' contains no values.")
        [first, ..] -> Ok(first)
      }
    }
    ObjectValue ->
      Error("Path '" <> path <> "' contains an object, not a value.")
    Missing -> Error("Path '" <> path <> "' not found.")
  }
}

/// Get all keys recursively with their full paths
pub fn get_all_paths(ccl: CCL) -> List(String) {
  get_all_paths_helper(ccl, "")
}

fn get_all_paths_helper(ccl: CCL, prefix: String) -> List(String) {
  case ccl {
    ccl_core.CCL(map) -> {
      dict.to_list(map)
      |> list.flat_map(fn(pair) {
        let #(key, nested_ccl) = pair
        let current_path = case prefix {
          "" -> key
          _ -> prefix <> "." <> key
        }

        case key {
          "" -> []
          // Skip empty keys used for terminal values
          _ -> {
            case
              dict.size(case nested_ccl {
                ccl_core.CCL(inner_map) -> inner_map
              })
            {
              0 -> []
              // Skip empty structures 
              _ -> [
                current_path,
                ..get_all_paths_helper(nested_ccl, current_path)
              ]
            }
          }
        }
      })
    }
  }
}

/// Pretty print CCL structure for debugging
pub fn pretty_print_ccl(ccl: CCL) -> String {
  pretty_print_ccl_with_indent(ccl, 0)
}

fn pretty_print_ccl_with_indent(ccl: CCL, indent: Int) -> String {
  case ccl {
    ccl_core.CCL(map) -> {
      let entries = dict.to_list(map)
      case entries {
        [] -> "{}"
        _ -> {
          let indent_str = string.repeat(" ", indent)
          let formatted =
            list.map(entries, fn(pair) {
              let #(key, value) = pair
              let key_display = case key {
                "" -> "<empty>"
                _ -> "\"" <> key <> "\""
              }
              indent_str
              <> "  "
              <> key_display
              <> ": "
              <> pretty_print_ccl_with_indent(value, indent + 2)
            })
          "{\n" <> string.join(formatted, ",\n") <> "\n" <> indent_str <> "}"
        }
      }
    }
  }
}

// === COMMENT FILTERING ===

/// Filter out entries with specific keys (useful for removing comments)
/// Takes a list of entries and excludes any with keys matching the exclude list
pub fn filter_keys(
  entries: List(Entry),
  exclude_keys: List(String),
) -> List(Entry) {
  list.filter(entries, fn(entry) { !list.contains(exclude_keys, entry.key) })
}
