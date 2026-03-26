/// Typed access functions for CCL values.
///
/// These are optional library conveniences per the CCL docs.
/// All navigate a CCL structure by path and extract typed values.
///
/// Default behaviours (configurable via `_with` variants):
/// - `boolean_strict`: only `true`/`false` (case-insensitive)
/// - `list_coercion_disabled`: `get_list` errors on non-list values
import ccl/types.{
  type AccessOptions, type CCL, type CCLValue, BooleanLenient, CclList,
  CclObject, CclString, CoercionEnabled,
}
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/string

/// Navigate to a path and return the string value.
pub fn get_string(ccl: CCL, path: List(String)) -> Result(String, String) {
  use value <- navigate(ccl, path)
  case value {
    CclString(s) -> Ok(s)
    CclObject(_) ->
      Error("Expected string, got object at " <> format_path(path))
    CclList(_) -> Error("Expected string, got list at " <> format_path(path))
  }
}

/// Navigate to a path and parse value as integer.
pub fn get_int(ccl: CCL, path: List(String)) -> Result(Int, String) {
  use str <- try_string(ccl, path)
  case int.parse(str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error("Not an integer: " <> string.inspect(str))
  }
}

/// Navigate to a path and parse value as boolean.
/// Uses `boolean_strict`: only `true`/`false`, case-insensitive.
pub fn get_bool(ccl: CCL, path: List(String)) -> Result(Bool, String) {
  get_bool_with(ccl, path, types.default_access_options())
}

/// Navigate to a path and parse value as boolean with configurable options.
pub fn get_bool_with(
  ccl: CCL,
  path: List(String),
  options: AccessOptions,
) -> Result(Bool, String) {
  use str <- try_string(ccl, path)
  let lower = string.lowercase(str)
  case options.boolean_parsing {
    BooleanLenient ->
      case lower {
        "true" | "yes" | "on" | "1" -> Ok(True)
        "false" | "no" | "off" | "0" -> Ok(False)
        _ -> Error("Not a boolean: " <> string.inspect(str))
      }
    _ ->
      case lower {
        "true" -> Ok(True)
        "false" -> Ok(False)
        _ -> Error("Not a boolean: " <> string.inspect(str))
      }
  }
}

/// Navigate to a path and parse value as float.
pub fn get_float(ccl: CCL, path: List(String)) -> Result(Float, String) {
  use str <- try_string(ccl, path)
  case float.parse(str) {
    Ok(f) -> Ok(f)
    Error(_) -> {
      // Try parsing as integer and converting
      case int.parse(str) {
        Ok(n) -> Ok(int.to_float(n))
        Error(_) -> Error("Not a float: " <> string.inspect(str))
      }
    }
  }
}

/// Navigate to a path and return list of string values.
/// Uses `list_coercion_disabled`: errors if value is not a list.
///
/// Handles the CCL pattern where lists are stored as objects with empty-key entries:
/// `items =\n  = a\n  = b` → `CclObject({"": CclList([CclString("a"), CclString("b")])})`
pub fn get_list(ccl: CCL, path: List(String)) -> Result(List(String), String) {
  get_list_with(ccl, path, types.default_access_options())
}

/// Navigate to a path and return list of string values with configurable options.
pub fn get_list_with(
  ccl: CCL,
  path: List(String),
  options: AccessOptions,
) -> Result(List(String), String) {
  use value <- navigate(ccl, path)
  case value {
    CclList(items) -> extract_string_list(items, path)
    // Check for the {"": CclList(...)} pattern (bare lists under named keys)
    CclObject(nested) -> {
      case dict.get(nested, "") {
        Ok(CclList(items)) -> extract_string_list(items, path)
        _ -> Error("Not a list at " <> format_path(path))
      }
    }
    CclString(s) ->
      case options.list_coercion {
        CoercionEnabled -> Ok([s])
        _ ->
          Error(
            "Not a list at " <> format_path(path) <> " (list_coercion_disabled)",
          )
      }
  }
}

/// Extract string values from a list of CCLValues.
fn extract_string_list(
  items: List(CCLValue),
  path: List(String),
) -> Result(List(String), String) {
  items
  |> list.try_map(fn(item) {
    case item {
      CclString(s) -> Ok(s)
      _ -> Error("List contains non-string item at " <> format_path(path))
    }
  })
}

/// Navigate a CCL structure by path, returning the value at the end.
fn navigate(
  ccl: CCL,
  path: List(String),
  then: fn(CCLValue) -> Result(a, String),
) -> Result(a, String) {
  case path {
    [] -> Error("Empty path")
    [key] -> {
      case dict.get(ccl, key) {
        Ok(value) -> then(value)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
    [key, ..rest] -> {
      case dict.get(ccl, key) {
        Ok(CclObject(nested)) -> navigate(nested, rest, then)
        Ok(_) -> Error("Not an object at key: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
  }
}

/// Helper: navigate to path, extract string, then apply conversion.
fn try_string(
  ccl: CCL,
  path: List(String),
  convert: fn(String) -> Result(a, String),
) -> Result(a, String) {
  case get_string(ccl, path) {
    Ok(s) -> convert(s)
    Error(e) -> Error(e)
  }
}

/// Format a path for error messages.
fn format_path(path: List(String)) -> String {
  string.join(path, ".")
}
