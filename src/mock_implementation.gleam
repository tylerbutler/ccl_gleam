/// Mock CCL implementation for testing the test runner itself.
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import test_runner.{
  type CCL, type CclImplementation, type Entry, CclImplementation, CclList,
  CclObject, CclString, Entry,
}
import test_types.{type ImplementationConfig, ImplementationConfig}

/// Implementation capabilities config.
/// Declares which functions, behaviors, features, and variants
/// this implementation supports. The test runner uses this to
/// filter tests — only compatible tests are run.
pub fn config() -> ImplementationConfig {
  ImplementationConfig(
    functions: ["parse", "print", "build_hierarchy"],
    behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
    variants: ["reference_compliant"],
    features: [],
  )
}

/// Create a mock CCL implementation.
pub fn new() -> CclImplementation {
  CclImplementation(
    parse: mock_parse,
    parse_indented: mock_parse_indented,
    print: mock_print,
    filter: mock_filter,
    compose: mock_compose,
    build_hierarchy: mock_build_hierarchy,
    get_string: mock_get_string,
    get_int: mock_get_int,
    get_bool: mock_get_bool,
    get_float: mock_get_float,
    get_list: mock_get_list,
  )
}

fn mock_parse(input: String) -> Result(List(Entry), String) {
  let normalized = string.replace(input, "\r\n", "\n")
  let lines = string.split(normalized, "\n")

  lines
  |> list.filter(fn(line) { !string.is_empty(string.trim(line)) })
  |> list.try_map(parse_line)
}

fn parse_line(line: String) -> Result(Entry, String) {
  case string.split_once(line, " = ") {
    Ok(#(key, value)) -> Ok(Entry(key: key, value: value))
    Error(_) ->
      case string.split_once(line, "=") {
        Ok(#(key, value)) ->
          Ok(Entry(key: string.trim(key), value: string.trim(value)))
        Error(_) -> Error("Invalid line: " <> line)
      }
  }
}

fn mock_parse_indented(input: String) -> Result(List(Entry), String) {
  let lines = string.split(input, "\n")
  let dedented =
    lines
    |> list.map(string.trim_start)
    |> string.join("\n")
  mock_parse(dedented)
}

fn mock_filter(entries: List(Entry)) -> List(Entry) {
  entries |> list.filter(fn(e: Entry) { e.key != "/" })
}

fn mock_compose(left: List(Entry), right: List(Entry)) -> List(Entry) {
  list.append(left, right)
}

fn mock_print(entries: List(Entry)) -> String {
  entries
  |> list.map(fn(e: Entry) { e.key <> " = " <> e.value })
  |> string.join("\n")
}

fn mock_build_hierarchy(_entries: List(Entry)) -> CCL {
  dict.new()
}

fn mock_get_string(ccl: CCL, path: List(String)) -> Result(String, String) {
  case path {
    [] -> Error("Empty path")
    [key] ->
      case dict.get(ccl, key) {
        Ok(CclString(s)) -> Ok(s)
        Ok(CclList([first, ..])) -> Ok(first)
        Ok(_) -> Error("Not a string: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    [key, ..rest] ->
      case dict.get(ccl, key) {
        Ok(CclObject(obj)) -> mock_get_string(obj, rest)
        Ok(_) -> Error("Not an object: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
  }
}

fn mock_get_int(ccl: CCL, path: List(String)) -> Result(Int, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case int.parse(str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error("Not an integer: " <> str)
  }
}

fn mock_get_bool(ccl: CCL, path: List(String)) -> Result(Bool, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case string.lowercase(str) {
    "true" -> Ok(True)
    "false" -> Ok(False)
    _ -> Error("Not a boolean: " <> str)
  }
}

fn mock_get_float(ccl: CCL, path: List(String)) -> Result(Float, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case float.parse(str) {
    Ok(f) -> Ok(f)
    Error(_) ->
      case int.parse(str) {
        Ok(n) -> Ok(int.to_float(n))
        Error(_) -> Error("Not a float: " <> str)
      }
  }
}

fn mock_get_list(ccl: CCL, path: List(String)) -> Result(List(String), String) {
  case path {
    [] -> Error("Empty path")
    [key] ->
      case dict.get(ccl, key) {
        Ok(CclList(l)) -> Ok(l)
        Ok(CclString(s)) -> Ok([s])
        Ok(_) -> Error("Not a list: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    [key, ..rest] ->
      case dict.get(ccl, key) {
        Ok(CclObject(obj)) -> mock_get_list(obj, rest)
        Ok(_) -> Error("Not an object: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
  }
}
