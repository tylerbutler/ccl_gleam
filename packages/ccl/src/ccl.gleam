import ccl_core.{type CCL, type Entry}
import gleam/dict
import gleam/float
import gleam/int
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

// === PRETTY PRINTING API ===

/// Pretty print CCL entries as canonical CCL text
pub fn pretty_print_entries(entries: List(ccl_core.Entry)) -> String {
  entries
  |> list.map(format_entry(_, 0))
  |> string.join("\n")
}

/// Pretty print CCL structure as canonical CCL text
pub fn pretty_print_ccl(ccl: CCL) -> String {
  format_ccl_recursive(ccl, 0)
}

// === INTERNAL PRETTY PRINTING HELPERS ===

/// Format a single entry with proper indentation
fn format_entry(entry: ccl_core.Entry, indent_level: Int) -> String {
  let ccl_core.Entry(key, value) = entry
  let indent = string.repeat("  ", indent_level)
  
  case is_multiline(value) {
    True -> format_multiline_entry(key, value, indent_level)
    False -> indent <> normalize_key(key) <> " = " <> normalize_value(value)
  }
}

/// Check if a value spans multiple lines
fn is_multiline(value: String) -> Bool {
  string.contains(value, "\n")
}

/// Format a multiline entry with proper continuation indentation
fn format_multiline_entry(key: String, value: String, indent_level: Int) -> String {
  let indent = string.repeat("  ", indent_level)
  let lines = string.split(value, "\n")
  let formatted_key = normalize_key(key) <> " ="
  
  case lines {
    [] -> indent <> formatted_key
    [single_line] -> indent <> formatted_key <> " " <> normalize_value(single_line)
    [first_line, ..rest_lines] -> {
      let first_part = case normalize_value(first_line) {
        "" -> indent <> formatted_key
        first_val -> indent <> formatted_key <> " " <> first_val
      }
      let continuation_indent = string.repeat("  ", indent_level + 1)
      let formatted_rest = 
        list.map(rest_lines, fn(line) {
          case normalize_value(line) {
            "" -> ""  // Empty lines stay empty
            val -> continuation_indent <> val
          }
        })
      string.join([first_part, ..formatted_rest], "\n")
    }
  }
}

/// Format CCL structure recursively
fn format_ccl_recursive(ccl: CCL, indent_level: Int) -> String {
  case ccl {
    ccl_core.CCL(map) -> {
      dict.to_list(map)
      |> list.map(fn(entry) {
        let #(key, sub_ccl) = entry
        format_ccl_entry(key, sub_ccl, indent_level)
      })
      |> string.join("\n")
    }
  }
}

/// Format a CCL structure entry (key-value pair where value is nested CCL)
fn format_ccl_entry(key: String, sub_ccl: CCL, indent_level: Int) -> String {
  let indent = string.repeat("  ", indent_level)
  let formatted_key = normalize_key(key)
  
  case sub_ccl {
    ccl_core.CCL(map) -> {
      case dict.size(map) {
        0 -> {
          // Terminal empty value
          case formatted_key {
            "" -> indent <> "= "  // Empty key (list item) with empty value
            _ -> indent <> formatted_key <> " = "  // Regular key with empty value
          }
        }
        _ -> {
          case formatted_key {
            "" -> {
              // Empty key - check if this is a terminal value or nested structure
              let terminal_values = get_all_terminal_values_from_ccl(sub_ccl)
              case terminal_values {
                [single_value] -> indent <> "= " <> normalize_value(single_value)
                _ -> format_ccl_recursive(sub_ccl, indent_level)  // Complex nested structure
              }
            }
            _ -> {
              let nested_content = format_ccl_recursive(sub_ccl, indent_level + 1)
              case string.trim(nested_content) {
                "" -> indent <> formatted_key <> " ="
                content -> indent <> formatted_key <> " =\n" <> content
              }
            }
          }
        }
      }
    }
  }
}

/// Get all terminal values from a CCL structure
fn get_all_terminal_values_from_ccl(ccl: CCL) -> List(String) {
  case ccl {
    ccl_core.CCL(map) -> {
      dict.to_list(map)
      |> list.flat_map(fn(pair) {
        let #(key, nested_ccl) = pair
        case nested_ccl {
          ccl_core.CCL(inner_map) -> {
            case dict.size(inner_map) {
              0 -> [key]  // Terminal value found
              _ -> get_all_terminal_values_from_ccl(nested_ccl)  // Keep searching deeper
            }
          }
        }
      })
    }
  }
}

/// Normalize a key according to CCL formatting rules
fn normalize_key(key: String) -> String {
  string.trim(key)
}

/// Normalize a value according to CCL formatting rules  
fn normalize_value(value: String) -> String {
  // Trim leading spaces, preserve trailing tabs as per tab_preservation_in_values test
  lstrip_spaces(value)
  // Don't strip trailing whitespace to preserve tabs and trailing spaces as needed
}

/// Strip leading spaces only (not tabs)
fn lstrip_spaces(s: String) -> String {
  lstrip_while_char(s, " ")
}

/// Helper to strip characters from left
fn lstrip_while_char(s: String, char: String) -> String {
  case string.starts_with(s, char) {
    True -> lstrip_while_char(string.drop_start(s, 1), char)
    False -> s
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

// === TYPED PARSING LAYER ===

/// Types for typed parsing functionality
pub type ValueType {
  StringVal(String)
  IntVal(Int)
  FloatVal(Float)
  BoolVal(Bool)
  EmptyVal
}

/// Parse options for controlling type inference behavior
pub type ParseOptions {
  ParseOptions(parse_integers: Bool, parse_floats: Bool, parse_booleans: Bool)
}

/// Smart parsing options - all type parsing enabled
pub fn smart_options() -> ParseOptions {
  ParseOptions(parse_integers: True, parse_floats: True, parse_booleans: True)
}

/// Basic parsing options - no type inference, all strings
pub fn basic_options() -> ParseOptions {
  ParseOptions(
    parse_integers: False,
    parse_floats: False,
    parse_booleans: False,
  )
}

// === CORE TYPED PARSING FUNCTIONS ===

/// Parse a value as an integer
pub fn get_int(ccl: CCL, path: String) -> Result(Int, String) {
  case get_smart_value(ccl, path) {
    Ok(str_val) -> parse_int(str_val, path)
    Error(err) -> Error(err)
  }
}

/// Parse a value as a float
pub fn get_float(ccl: CCL, path: String) -> Result(Float, String) {
  case get_smart_value(ccl, path) {
    Ok(str_val) -> parse_float(str_val, path)
    Error(err) -> Error(err)
  }
}

/// Parse a value as a boolean
pub fn get_bool(ccl: CCL, path: String) -> Result(Bool, String) {
  case get_smart_value(ccl, path) {
    Ok(str_val) -> parse_bool(str_val, path)
    Error(err) -> Error(err)
  }
}

/// Parse a value with automatic type inference using smart options
pub fn get_typed_value(ccl: CCL, path: String) -> Result(ValueType, String) {
  get_typed_value_with_options(ccl, path, smart_options())
}

/// Parse a value with custom parsing options
pub fn get_typed_value_with_options(
  ccl: CCL,
  path: String,
  options: ParseOptions,
) -> Result(ValueType, String) {
  case get_smart_value(ccl, path) {
    Ok("") -> Ok(EmptyVal)
    Ok(str_val) -> {
      // Try parsing in priority order: int -> float -> bool -> string
      // Integers win over booleans in overlapping cases (1/0) since booleans have many non-numeric forms
      case options.parse_integers, try_parse_int(str_val) {
        True, Ok(int_val) -> Ok(IntVal(int_val))
        _, _ ->
          case options.parse_floats, try_parse_float(str_val) {
            True, Ok(float_val) -> Ok(FloatVal(float_val))
            _, _ ->
              case options.parse_booleans, try_parse_bool(str_val) {
                True, Ok(bool_val) -> Ok(BoolVal(bool_val))
                _, _ -> Ok(StringVal(str_val))
              }
          }
      }
    }
    Error(err) -> Error(err)
  }
}

// === INTERNAL PARSING HELPERS ===

/// Parse integer with path context for better error messages
fn parse_int(value: String, path: String) -> Result(Int, String) {
  let trimmed = string.trim(value)
  case int.parse(trimmed) {
    Ok(n) -> Ok(n)
    Error(_) -> {
      let suggestion = case trimmed {
        "" ->
          "Hint: Empty values cannot be integers. Use get_value() for strings or provide a default."
        _ -> {
          case string.contains(trimmed, ".") {
            True ->
              "Hint: '"
              <> trimmed
              <> "' contains a decimal. Use get_float() or remove the decimal point."
            False ->
              case string.contains(trimmed, ",") {
                True -> "Hint: Remove commas from numbers (use 1234 not 1,234)."
                False -> "Hint: Expected a whole number like 42, -7, or 0."
              }
          }
        }
      }
      Error(
        "Cannot parse '"
        <> value
        <> "' as integer at path '"
        <> path
        <> "'.\n"
        <> suggestion,
      )
    }
  }
}

/// Parse float with path context for better error messages
fn parse_float(value: String, path: String) -> Result(Float, String) {
  let trimmed = string.trim(value)
  case float.parse(trimmed) {
    Ok(f) -> Ok(f)
    Error(_) -> {
      let suggestion = case trimmed {
        "" ->
          "Hint: Empty values cannot be floats. Use get_value() for strings or provide a default."
        _ -> {
          case string.contains(trimmed, ",") {
            True ->
              "Hint: Remove commas from numbers (use 1234.56 not 1,234.56)."
            False ->
              case string.starts_with(trimmed, ".") {
                True ->
                  "Hint: Add leading zero (use '0"
                  <> trimmed
                  <> "' instead of '"
                  <> trimmed
                  <> "')."
                False ->
                  "Hint: Expected a decimal number like 3.14, -2.5, or 0.0."
              }
          }
        }
      }
      Error(
        "Cannot parse '"
        <> value
        <> "' as float at path '"
        <> path
        <> "'.\n"
        <> suggestion,
      )
    }
  }
}

/// Parse boolean with path context for better error messages
fn parse_bool(value: String, path: String) -> Result(Bool, String) {
  let trimmed = string.trim(string.lowercase(value))
  case trimmed {
    "true" | "yes" | "on" | "1" -> Ok(True)
    "false" | "no" | "off" | "0" -> Ok(False)
    _ -> {
      let suggestion = case trimmed {
        "" ->
          "Hint: Empty values cannot be booleans. Use get_value() for strings."
        "y" | "n" -> "Hint: Use full words: 'yes' or 'no'."
        "t" | "f" -> "Hint: Use full words: 'true' or 'false'."
        _ -> {
          case
            string.contains(trimmed, "enabled")
            || string.contains(trimmed, "disabled")
          {
            True ->
              "Hint: Use 'true'/'false', 'yes'/'no', 'on'/'off', or '1'/'0'."
            False ->
              "Hint: Valid values are 'true', 'false', 'yes', 'no', 'on', 'off', '1', or '0'."
          }
        }
      }
      Error(
        "Cannot parse '"
        <> value
        <> "' as boolean at path '"
        <> path
        <> "'.\n"
        <> suggestion,
      )
    }
  }
}

/// Try to parse integer without error context (for type inference)
fn try_parse_int(value: String) -> Result(Int, Nil) {
  let trimmed = string.trim(value)
  case int.parse(trimmed) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(Nil)
  }
}

/// Try to parse float without error context (for type inference)
fn try_parse_float(value: String) -> Result(Float, Nil) {
  let trimmed = string.trim(value)
  case float.parse(trimmed) {
    Ok(f) -> Ok(f)
    Error(_) -> Error(Nil)
  }
}

/// Try to parse boolean without error context (for type inference)
fn try_parse_bool(value: String) -> Result(Bool, Nil) {
  let trimmed = string.trim(string.lowercase(value))
  case trimmed {
    "true" | "yes" | "on" | "1" -> Ok(True)
    "false" | "no" | "off" | "0" -> Ok(False)
    _ -> Error(Nil)
  }
}
