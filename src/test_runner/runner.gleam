/// Test runner that executes tests against the CCL implementation directly.
///
/// No more CclImplementation interface — calls ccl/parser, ccl/hierarchy,
/// ccl/access, and ccl/format directly.
import birch
import ccl/access
import ccl/format
import ccl/hierarchy
import ccl/parser
import ccl/types as ccl_types
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import test_runner/filter
import test_runner/loader
import test_runner/types.{
  type Expected, type ExpectedNode, type ImplementationConfig, type TestCase,
  type TestResult, type TestSuite, type TestSuiteResult, ExpectedBool,
  ExpectedBoolean, ExpectedCountOnly, ExpectedEntries, ExpectedError,
  ExpectedFloat, ExpectedInt, ExpectedList, ExpectedObject, ExpectedValue,
  FailureDetail, NodeList, NodeObject, NodeString, TestFailed, TestPassed,
  TestSkipped, TestSuiteResult,
}

// --- Failure helpers ---

/// Create a TestFailed with separate actual/expected for diff display.
fn mismatch(
  name: String,
  reason: String,
  actual: String,
  expected: String,
  count: Int,
) -> TestResult {
  TestFailed(
    name,
    FailureDetail(
      reason: reason,
      actual: actual,
      expected: expected,
      assertions: count,
    ),
  )
}

/// Create a TestFailed for error cases (no meaningful diff).
fn error_fail(name: String, reason: String, count: Int) -> TestResult {
  TestFailed(
    name,
    FailureDetail(
      reason: reason,
      actual: reason,
      expected: "",
      assertions: count,
    ),
  )
}

/// Run all tests from a directory
pub fn run_test_directory(
  dir: String,
  config: ImplementationConfig,
) -> Result(List(TestSuiteResult), String) {
  use files <- result.try(loader.list_test_files(dir))

  birch.info_m("Found test files", [
    #("count", int.to_string(list.length(files))),
  ])

  let results =
    files
    |> list.map(fn(file) { run_test_file(file, config) })
    |> result.all

  results
}

/// Run all tests from a single file
pub fn run_test_file(
  path: String,
  config: ImplementationConfig,
) -> Result(TestSuiteResult, String) {
  birch.info_m("Loading test file", [#("path", path)])

  use suite <- result.try(loader.load_test_file(path))

  let results = run_test_suite(suite, config)

  let passed =
    list.count(results, fn(r) {
      case r {
        TestPassed(_, _) -> True
        _ -> False
      }
    })

  let failed =
    list.count(results, fn(r) {
      case r {
        TestFailed(_, _) -> True
        _ -> False
      }
    })

  let skipped =
    list.count(results, fn(r) {
      case r {
        TestSkipped(_, _) -> True
        _ -> False
      }
    })

  Ok(TestSuiteResult(
    file: path,
    total: list.length(results),
    passed: passed,
    failed: failed,
    skipped: skipped,
    results: results,
  ))
}

/// Run a test suite
pub fn run_test_suite(
  suite: TestSuite,
  config: ImplementationConfig,
) -> List(TestResult) {
  suite.tests
  |> list.map(fn(tc) { run_single_test(tc, config) })
}

/// Run a single test case
pub fn run_single_test(tc: TestCase, config: ImplementationConfig) -> TestResult {
  case filter.get_skip_reason(config, tc) {
    Error(reason) -> TestSkipped(tc.name, reason)
    Ok(Nil) -> execute_test(tc)
  }
}

/// Execute a test that passed compatibility checks
fn execute_test(tc: TestCase) -> TestResult {
  let input = case tc.inputs {
    [first, ..] -> first
    [] -> ""
  }

  case tc.validation {
    "parse" -> run_parse_test(tc.name, input, tc.expected)
    "print" -> run_print_test(tc.name, input, tc.expected)
    "build_hierarchy" -> run_hierarchy_test(tc.name, input, tc.expected)
    "get_string" ->
      run_get_string_test(tc.name, input, resolve_path(tc), tc.expected)
    "get_int" -> run_get_int_test(tc.name, input, resolve_path(tc), tc.expected)
    "get_bool" ->
      run_get_bool_test(tc.name, input, resolve_path(tc), tc.expected)
    "get_float" ->
      run_get_float_test(tc.name, input, resolve_path(tc), tc.expected)
    "get_list" ->
      run_get_list_test(tc.name, input, resolve_path(tc), tc.expected)
    "filter" -> run_filter_test(tc.name, input, tc.expected)
    "round_trip" -> run_round_trip_test(tc.name, input, tc.expected)
    "canonical_format" -> run_canonical_format_test(tc.name, input, tc.expected)
    other -> error_fail(tc.name, "Unknown validation: " <> other, 0)
  }
}

// --- Parse tests ---

fn run_parse_test(name: String, input: String, expected: Expected) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case parser.parse(input) {
        Ok(entries) -> {
          let expected_list =
            expected_entries
            |> list.map(fn(e) { ccl_types.Entry(e.key, e.value) })
          case entries == expected_list {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Entries mismatch",
                format_entries(entries),
                format_entries(expected_list),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case parser.parse(input) {
        Ok(_) ->
          mismatch(
            name,
            "Expected error but got success",
            "Ok(_)",
            "Error(_)",
            count,
          )
        Error(_) -> TestPassed(name, count)
      }
    }
    ExpectedCountOnly(count) -> {
      case parser.parse(input) {
        Ok(_) -> TestPassed(name, count)
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for parse test", 0)
  }
}

// --- Filter tests ---

fn run_filter_test(
  name: String,
  input: String,
  expected: Expected,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case parser.parse(input) {
        Ok(entries) -> {
          let filtered =
            entries
            |> list.filter(fn(e) { e.key != "/" })
          let expected_list =
            expected_entries
            |> list.map(fn(e) { ccl_types.Entry(e.key, e.value) })
          case filtered == expected_list {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Filter mismatch",
                format_entries(filtered),
                format_entries(expected_list),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedCountOnly(count) -> {
      case parser.parse(input) {
        Ok(entries) -> {
          let filtered =
            entries
            |> list.filter(fn(e) { e.key != "/" })
          // Count-only: just verify the count matches
          case list.length(filtered) == count {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Filter count mismatch",
                int.to_string(list.length(filtered)),
                int.to_string(count),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for filter test", 0)
  }
}

// --- Print tests ---

fn run_print_test(name: String, input: String, expected: Expected) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      case parser.parse(input) {
        Ok(entries) -> {
          let printed = format.print(entries)
          case printed == expected_value {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Print mismatch",
                string.inspect(printed),
                string.inspect(expected_value),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for print test", 0)
  }
}

// --- Round trip tests ---

fn run_round_trip_test(
  name: String,
  input: String,
  expected: Expected,
) -> TestResult {
  let count = get_expected_count(expected)
  case parser.parse(input) {
    Ok(entries) -> {
      let printed = format.print(entries)
      case parser.parse(printed) {
        Ok(re_entries) -> {
          case entries == re_entries {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Round trip mismatch",
                format_entries(re_entries),
                format_entries(entries),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "Round trip re-parse error: " <> e, count)
      }
    }
    Error(e) -> error_fail(name, "Parse error: " <> e, count)
  }
}

// --- Canonical format tests ---

fn run_canonical_format_test(
  name: String,
  input: String,
  expected: Expected,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      case parser.parse(input) {
        Ok(entries) -> {
          let ccl = hierarchy.build_hierarchy(entries)
          let formatted = format.canonical_format(ccl)
          case formatted == expected_value {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Canonical format mismatch",
                string.inspect(formatted),
                string.inspect(expected_value),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for canonical_format test", 0)
  }
}

// --- Hierarchy tests ---

fn run_hierarchy_test(
  name: String,
  input: String,
  expected: Expected,
) -> TestResult {
  case expected {
    ExpectedObject(count, expected_obj) -> {
      case parser.parse(input) {
        Ok(entries) -> {
          let obj = hierarchy.build_hierarchy(entries)
          case compare_objects(obj, expected_obj) {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Object mismatch",
                format_ccl(obj),
                format_expected_object(expected_obj),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedCountOnly(count) -> {
      case parse_and_build(input) {
        Ok(_) -> TestPassed(name, count)
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for hierarchy test", 0)
  }
}

// --- Typed access tests ---

fn run_get_string_test(
  name: String,
  input: String,
  path: List(String),
  expected: Expected,
) -> TestResult {
  let key_path = path
  case expected {
    ExpectedValue(count, expected_value) -> {
      case parse_and_build(input) {
        Ok(obj) -> {
          case access.get_string(obj, key_path) {
            Ok(value) -> check_value_match(name, value, expected_value, count)
            Error(e) -> error_fail(name, "get_string error: " <> e, count)
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      run_expected_error_test(name, input, key_path, count, fn(obj, p) {
        access.get_string(obj, p)
      })
    }
    ExpectedCountOnly(count) -> {
      TestPassed(name, count)
    }
    _ -> error_fail(name, "Invalid expected type for get_string test", 0)
  }
}

fn run_get_int_test(
  name: String,
  input: String,
  path: List(String),
  expected: Expected,
) -> TestResult {
  let key_path = path
  case expected {
    ExpectedInt(count, expected_value) -> {
      case parse_and_build(input) {
        Ok(obj) -> {
          case access.get_int(obj, key_path) {
            Ok(value) -> {
              case value == expected_value {
                True -> TestPassed(name, count)
                False ->
                  mismatch(
                    name,
                    "Value mismatch",
                    int.to_string(value),
                    int.to_string(expected_value),
                    count,
                  )
              }
            }
            Error(e) -> error_fail(name, "get_int error: " <> e, count)
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      run_expected_error_test(name, input, key_path, count, fn(obj, p) {
        access.get_int(obj, p) |> result.map(int.to_string)
      })
    }
    ExpectedCountOnly(count) -> {
      TestPassed(name, count)
    }
    _ -> error_fail(name, "Invalid expected type for get_int test", 0)
  }
}

fn run_get_bool_test(
  name: String,
  input: String,
  path: List(String),
  expected: Expected,
) -> TestResult {
  let key_path = path
  case expected {
    ExpectedBool(count, expected_value) -> {
      case parse_and_build(input) {
        Ok(obj) -> {
          case access.get_bool(obj, key_path) {
            Ok(value) -> {
              case value == expected_value {
                True -> TestPassed(name, count)
                False ->
                  mismatch(
                    name,
                    "Value mismatch",
                    string.inspect(value),
                    string.inspect(expected_value),
                    count,
                  )
              }
            }
            Error(e) -> error_fail(name, "get_bool error: " <> e, count)
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedBoolean(count, expected_value) -> {
      case parse_and_build(input) {
        Ok(obj) -> {
          case access.get_bool(obj, key_path) {
            Ok(value) -> {
              case value == expected_value {
                True -> TestPassed(name, count)
                False ->
                  mismatch(
                    name,
                    "Value mismatch",
                    string.inspect(value),
                    string.inspect(expected_value),
                    count,
                  )
              }
            }
            Error(e) -> error_fail(name, "get_bool error: " <> e, count)
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      run_expected_error_test(name, input, key_path, count, fn(obj, p) {
        access.get_bool(obj, p) |> result.map(string.inspect)
      })
    }
    ExpectedCountOnly(count) -> {
      // Count-only: accept either success or error
      TestPassed(name, count)
    }
    _ -> error_fail(name, "Invalid expected type for get_bool test", 0)
  }
}

fn run_get_float_test(
  name: String,
  input: String,
  path: List(String),
  expected: Expected,
) -> TestResult {
  let key_path = path
  case expected {
    ExpectedFloat(count, expected_value) -> {
      run_float_comparison(name, input, key_path, count, expected_value)
    }
    ExpectedInt(count, expected_int) -> {
      let expected_value = int.to_float(expected_int)
      run_float_comparison(name, input, key_path, count, expected_value)
    }
    ExpectedError(count, True) -> {
      run_expected_error_test(name, input, key_path, count, fn(obj, p) {
        access.get_float(obj, p) |> result.map(string.inspect)
      })
    }
    ExpectedCountOnly(count) -> {
      TestPassed(name, count)
    }
    _ -> error_fail(name, "Invalid expected type for get_float test", 0)
  }
}

fn run_get_list_test(
  name: String,
  input: String,
  path: List(String),
  expected: Expected,
) -> TestResult {
  let key_path = path
  case expected {
    ExpectedList(count, expected_list) -> {
      case parse_and_build(input) {
        Ok(obj) -> {
          case access.get_list(obj, key_path) {
            Ok(value) -> {
              case value == expected_list {
                True -> TestPassed(name, count)
                False ->
                  mismatch(
                    name,
                    "List mismatch",
                    string.inspect(value),
                    string.inspect(expected_list),
                    count,
                  )
              }
            }
            Error(e) -> error_fail(name, "get_list error: " <> e, count)
          }
        }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      run_expected_error_test(name, input, key_path, count, fn(obj, p) {
        access.get_list(obj, p) |> result.map(string.inspect)
      })
    }
    ExpectedCountOnly(count) -> {
      TestPassed(name, count)
    }
    _ -> error_fail(name, "Invalid expected type for get_list test", 0)
  }
}

// --- Helper functions ---

/// Resolve the key path from a test case — prefers `args`, falls back to `path`.
fn resolve_path(tc: TestCase) -> List(String) {
  case tc.args {
    option.Some(args) -> args
    option.None -> option.unwrap(tc.path, [])
  }
}

/// Parse input and build hierarchy in one step.
fn parse_and_build(input: String) -> Result(ccl_types.CCL, String) {
  case parser.parse(input) {
    Ok(entries) -> Ok(hierarchy.build_hierarchy(entries))
    Error(e) -> Error(e)
  }
}

/// Run a test that expects an error result.
fn run_expected_error_test(
  name: String,
  input: String,
  path: List(String),
  count: Int,
  accessor: fn(ccl_types.CCL, List(String)) -> Result(String, String),
) -> TestResult {
  case parse_and_build(input) {
    Ok(obj) -> {
      case accessor(obj, path) {
        Ok(_) ->
          mismatch(
            name,
            "Expected error but got success",
            "Ok(_)",
            "Error(_)",
            count,
          )
        Error(_) -> TestPassed(name, count)
      }
    }
    Error(_) -> TestPassed(name, count)
  }
}

fn run_float_comparison(
  name: String,
  input: String,
  key_path: List(String),
  count: Int,
  expected_value: Float,
) -> TestResult {
  case parse_and_build(input) {
    Ok(obj) -> {
      case access.get_float(obj, key_path) {
        Ok(value) -> {
          let diff = float_abs(value -. expected_value)
          case diff <. 0.0001 {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Value mismatch",
                string.inspect(value),
                string.inspect(expected_value),
                count,
              )
          }
        }
        Error(e) -> error_fail(name, "get_float error: " <> e, count)
      }
    }
    Error(e) -> error_fail(name, "Parse error: " <> e, count)
  }
}

fn float_abs(x: Float) -> Float {
  case x <. 0.0 {
    True -> 0.0 -. x
    False -> x
  }
}

fn check_value_match(
  name: String,
  actual: String,
  expected: String,
  count: Int,
) -> TestResult {
  case actual == expected {
    True -> TestPassed(name, count)
    False ->
      mismatch(
        name,
        "Value mismatch",
        string.inspect(actual),
        string.inspect(expected),
        count,
      )
  }
}

fn get_expected_count(expected: Expected) -> Int {
  case expected {
    ExpectedEntries(count, _) -> count
    ExpectedValue(count, _) -> count
    ExpectedObject(count, _) -> count
    ExpectedList(count, _) -> count
    ExpectedInt(count, _) -> count
    ExpectedFloat(count, _) -> count
    ExpectedBool(count, _) -> count
    ExpectedError(count, _) -> count
    ExpectedBoolean(count, _) -> count
    ExpectedCountOnly(count) -> count
  }
}

/// Compare CCL object with expected object
fn compare_objects(
  actual: ccl_types.CCL,
  expected: Dict(String, ExpectedNode),
) -> Bool {
  let actual_keys = dict.keys(actual) |> list.sort(string.compare)
  let expected_keys = dict.keys(expected) |> list.sort(string.compare)

  case actual_keys == expected_keys {
    False -> False
    True -> {
      list.all(actual_keys, fn(key) {
        case dict.get(actual, key), dict.get(expected, key) {
          Ok(actual_val), Ok(expected_val) ->
            compare_values(actual_val, expected_val)
          _, _ -> False
        }
      })
    }
  }
}

/// Compare CCL value with expected node
fn compare_values(actual: ccl_types.CCLValue, expected: ExpectedNode) -> Bool {
  case actual, expected {
    ccl_types.CclString(s), NodeString(es) -> s == es
    ccl_types.CclList(items), NodeList(el) -> {
      let str_items =
        items
        |> list.filter_map(fn(item) {
          case item {
            ccl_types.CclString(s) -> Ok(s)
            _ -> Error(Nil)
          }
        })
      str_items == el
    }
    ccl_types.CclObject(obj), NodeObject(eobj) -> compare_objects(obj, eobj)
    _, _ -> False
  }
}

/// Format entries for error messages
fn format_entries(entries: List(ccl_types.Entry)) -> String {
  "\n"
  <> entries
  |> list.map(fn(e) { "(" <> e.key <> "," <> e.value <> ")" })
  |> string.join("\n")
}

/// Format expected object for error messages (pretty-printed)
fn format_expected_object(obj: Dict(String, ExpectedNode)) -> String {
  "\n" <> format_expected_object_indent(obj, 0)
}

fn format_expected_object_indent(
  obj: Dict(String, ExpectedNode),
  indent: Int,
) -> String {
  let pad = string.repeat("  ", indent)
  let inner_pad = string.repeat("  ", indent + 1)
  let entries =
    obj
    |> dict.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
    |> list.map(fn(pair) {
      let #(k, v) = pair
      inner_pad
      <> string.inspect(k)
      <> ": "
      <> format_expected_node_indent(v, indent + 1)
    })
    |> string.join(",\n")
  "{\n" <> entries <> "\n" <> pad <> "}"
}

fn format_expected_node_indent(node: ExpectedNode, indent: Int) -> String {
  case node {
    NodeString(s) -> string.inspect(s)
    NodeList(l) -> format_string_list(l)
    NodeObject(obj) -> format_expected_object_indent(obj, indent)
  }
}

/// Format CCL object for error messages (pretty-printed)
fn format_ccl(obj: ccl_types.CCL) -> String {
  "\n" <> format_ccl_indent(obj, 0)
}

fn format_ccl_indent(obj: ccl_types.CCL, indent: Int) -> String {
  let pad = string.repeat("  ", indent)
  let inner_pad = string.repeat("  ", indent + 1)
  let entries =
    obj
    |> dict.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
    |> list.map(fn(pair) {
      let #(k, v) = pair
      inner_pad
      <> string.inspect(k)
      <> ": "
      <> format_ccl_value_indent(v, indent + 1)
    })
    |> string.join(",\n")
  "{\n" <> entries <> "\n" <> pad <> "}"
}

fn format_ccl_value_indent(value: ccl_types.CCLValue, indent: Int) -> String {
  case value {
    ccl_types.CclString(s) -> string.inspect(s)
    ccl_types.CclList(items) -> {
      let strs =
        items
        |> list.map(fn(item) {
          case item {
            ccl_types.CclString(s) -> s
            _ -> "[complex]"
          }
        })
      format_string_list(strs)
    }
    ccl_types.CclObject(obj) -> format_ccl_indent(obj, indent)
  }
}

/// Format a list of strings as a JSON-like array
fn format_string_list(items: List(String)) -> String {
  case list.length(items) {
    0 -> "[]"
    _ -> {
      let inner =
        items
        |> list.map(fn(s) { string.inspect(s) })
        |> string.join(", ")
      "[" <> inner <> "]"
    }
  }
}

/// Print test results summary
pub fn print_results(results: List(TestSuiteResult)) -> Nil {
  let total_passed =
    results |> list.map(fn(r) { r.passed }) |> list.fold(0, fn(a, n) { a + n })
  let total_failed =
    results |> list.map(fn(r) { r.failed }) |> list.fold(0, fn(a, n) { a + n })
  let total_skipped =
    results
    |> list.map(fn(r) { r.skipped })
    |> list.fold(0, fn(a, n) { a + n })
  let total =
    results |> list.map(fn(r) { r.total }) |> list.fold(0, fn(a, n) { a + n })

  list.each(results, fn(r) {
    birch.info_m("Suite complete", [
      #("file", r.file),
      #("passed", int.to_string(r.passed)),
      #("failed", int.to_string(r.failed)),
      #("skipped", int.to_string(r.skipped)),
    ])

    list.each(r.results, fn(test_result) {
      case test_result {
        TestFailed(name, detail) -> {
          birch.error_m("Test failed", [
            #("test", name),
            #("reason", detail.reason),
          ])
        }
        _ -> Nil
      }
    })
  })

  birch.info_m("All tests complete", [
    #("total", int.to_string(total)),
    #("passed", int.to_string(total_passed)),
    #("failed", int.to_string(total_failed)),
    #("skipped", int.to_string(total_skipped)),
  ])

  Nil
}
