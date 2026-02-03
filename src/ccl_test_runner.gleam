/// CLI entry point for the CCL test runner
import argv
import birch
import birch/level
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import test_filter
import test_runner.{
  type CCL, type CclImplementation, type Entry, CclImplementation, CclList,
  CclObject, CclString, Entry,
}
import test_types.{type ImplementationConfig, ImplementationConfig}

pub fn main() {
  // Configure birch logging
  birch.configure([birch.config_level(level.Info)])

  let args = argv.load().arguments

  case args {
    ["--help"] | ["-h"] -> print_help()
    [test_dir] -> run_tests(test_dir, test_filter.parse_only_config())
    [test_dir, "--functions", funcs] -> {
      let functions = string.split(funcs, ",")
      let config =
        ImplementationConfig(
          functions: functions,
          behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
          variants: ["reference_compliant"],
          features: [],
        )
      run_tests(test_dir, config)
    }
    _ -> {
      io.println(
        "Usage: ccl_test_runner <test_dir> [--functions parse,print,...]",
      )
      io.println("Run with --help for more information")
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil

fn print_help() {
  io.println("CCL Test Runner")
  io.println("")
  io.println("Usage:")
  io.println("  ccl_test_runner <test_dir>")
  io.println("  ccl_test_runner <test_dir> --functions <func1,func2,...>")
  io.println("")
  io.println("Options:")
  io.println("  --help, -h     Show this help message")
  io.println("  --functions    Comma-separated list of implemented functions")
  io.println("")
  io.println("Available functions:")
  io.println("  parse          Basic key-value parsing")
  io.println("  print          Print entries back to CCL format")
  io.println("  build_hierarchy Convert flat entries to nested objects")
  io.println("  get_string     Get string value at path")
  io.println("  get_int        Get integer value at path")
  io.println("  get_bool       Get boolean value at path")
  io.println("  get_float      Get float value at path")
  io.println("  get_list       Get list value at path")
  io.println("")
  io.println("Examples:")
  io.println("  ccl_test_runner ../ccl-test-data/generated_tests/")
  io.println("  ccl_test_runner tests/ --functions parse,print,build_hierarchy")
}

fn run_tests(test_dir: String, config: ImplementationConfig) -> Nil {
  birch.info_m("Starting test runner", [
    #("dir", test_dir),
    #("functions", string.join(config.functions, ", ")),
  ])

  // Create a mock implementation for testing the runner itself
  let impl = mock_implementation()

  case test_runner.run_test_directory(test_dir, config, impl) {
    Ok(results) -> {
      test_runner.print_results(results)

      // Exit with error code if any tests failed
      let total_failed =
        results
        |> list.map(fn(r) { r.failed })
        |> list.fold(0, fn(acc, n) { acc + n })

      case total_failed > 0 {
        True -> halt(1)
        False -> Nil
      }
    }
    Error(e) -> {
      birch.error_m("Failed to run tests", [#("error", e)])
      halt(1)
    }
  }
}

/// Mock CCL implementation for testing the test runner
/// A real implementation would plug in actual CCL parsing/handling
fn mock_implementation() -> CclImplementation {
  CclImplementation(
    parse: mock_parse,
    print: mock_print,
    build_hierarchy: mock_build_hierarchy,
    get_string: mock_get_string,
    get_int: mock_get_int,
    get_bool: mock_get_bool,
    get_float: mock_get_float,
    get_list: mock_get_list,
  )
}

/// Simple mock parser implementation
fn mock_parse(input: String) -> Result(List(Entry), String) {
  // Normalize CRLF to LF
  let normalized = string.replace(input, "\r\n", "\n")

  // Split into lines and parse each
  let lines = string.split(normalized, "\n")

  lines
  |> list.filter(fn(line) { !string.is_empty(string.trim(line)) })
  |> list.try_map(parse_line)
}

fn parse_line(line: String) -> Result(Entry, String) {
  case string.split_once(line, " = ") {
    Ok(#(key, value)) -> Ok(Entry(key: key, value: value))
    Error(_) -> {
      // Try just "=" without spaces
      case string.split_once(line, "=") {
        Ok(#(key, value)) ->
          Ok(Entry(key: string.trim(key), value: string.trim(value)))
        Error(_) -> Error("Invalid line: " <> line)
      }
    }
  }
}

/// Mock print implementation
fn mock_print(entries: List(Entry)) -> String {
  entries
  |> list.map(fn(e) { e.key <> " = " <> e.value })
  |> string.join("\n")
}

/// Mock hierarchy builder
fn mock_build_hierarchy(entries: List(Entry)) -> CCL {
  entries
  |> list.fold(dict.new(), fn(acc, entry) {
    dict.insert(acc, entry.key, CclString(entry.value))
  })
}

/// Mock get_string
fn mock_get_string(ccl: CCL, path: List(String)) -> Result(String, String) {
  case path {
    [] -> Error("Empty path")
    [key] -> {
      case dict.get(ccl, key) {
        Ok(CclString(s)) -> Ok(s)
        Ok(CclList([first, ..])) -> Ok(first)
        Ok(_) -> Error("Not a string: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
    [key, ..rest] -> {
      case dict.get(ccl, key) {
        Ok(CclObject(obj)) -> mock_get_string(obj, rest)
        Ok(_) -> Error("Not an object: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
  }
}

/// Mock get_int
fn mock_get_int(ccl: CCL, path: List(String)) -> Result(Int, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case int.parse(str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error("Not an integer: " <> str)
  }
}

/// Mock get_bool
fn mock_get_bool(ccl: CCL, path: List(String)) -> Result(Bool, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case string.lowercase(str) {
    "true" -> Ok(True)
    "false" -> Ok(False)
    _ -> Error("Not a boolean: " <> str)
  }
}

/// Mock get_float
fn mock_get_float(ccl: CCL, path: List(String)) -> Result(Float, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case float.parse(str) {
    Ok(f) -> Ok(f)
    Error(_) -> {
      // Try parsing as int and converting
      case int.parse(str) {
        Ok(n) -> Ok(int.to_float(n))
        Error(_) -> Error("Not a float: " <> str)
      }
    }
  }
}

/// Mock get_list
fn mock_get_list(ccl: CCL, path: List(String)) -> Result(List(String), String) {
  case path {
    [] -> Error("Empty path")
    [key] -> {
      case dict.get(ccl, key) {
        Ok(CclList(l)) -> Ok(l)
        Ok(CclString(s)) -> Ok([s])
        Ok(_) -> Error("Not a list: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
    [key, ..rest] -> {
      case dict.get(ccl, key) {
        Ok(CclObject(obj)) -> mock_get_list(obj, rest)
        Ok(_) -> Error("Not an object: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
  }
}
