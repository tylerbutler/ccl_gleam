/// Test runner that executes tests against a CCL implementation
import birch
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import render/entries as render_entries
import render/theme
import render/value as render_value
import test_filter
import test_loader
import test_types.{
  type Expected, type ExpectedNode, type ImplementationConfig, type TestCase,
  type TestResult, type TestSuite, type TestSuiteResult, ExpectedBool,
  ExpectedEntries, ExpectedError, ExpectedFloat, ExpectedInt, ExpectedList,
  ExpectedObject, ExpectedValue, NodeList, NodeObject, NodeString, TestFailed,
  TestPassed, TestSkipped, TestSuiteResult,
}

/// Type alias for CCL entry
pub type Entry {
  Entry(key: String, value: String)
}

/// Type alias for CCL nested object
pub type CCL =
  Dict(String, CCLValue)

/// CCL value types
pub type CCLValue {
  CclString(String)
  CclList(List(String))
  CclObject(CCL)
}

/// CCL implementation interface - functions that implementations must provide
pub type CclImplementation {
  CclImplementation(
    parse: fn(String) -> Result(List(Entry), String),
    print: fn(List(Entry)) -> String,
    build_hierarchy: fn(List(Entry)) -> CCL,
    get_string: fn(CCL, List(String)) -> Result(String, String),
    get_int: fn(CCL, List(String)) -> Result(Int, String),
    get_bool: fn(CCL, List(String)) -> Result(Bool, String),
    get_float: fn(CCL, List(String)) -> Result(Float, String),
    get_list: fn(CCL, List(String)) -> Result(List(String), String),
  )
}

/// Run all tests from a directory against an implementation
pub fn run_test_directory(
  dir: String,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> Result(List(TestSuiteResult), String) {
  use files <- result.try(test_loader.list_test_files(dir))

  birch.info_m("Found test files", [
    #("count", int.to_string(list.length(files))),
  ])

  let results =
    files
    |> list.map(fn(file) { run_test_file(file, config, impl) })
    |> result.all

  results
}

/// Run all tests from a single file
pub fn run_test_file(
  path: String,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> Result(TestSuiteResult, String) {
  birch.info_m("Loading test file", [#("path", path)])

  use suite <- result.try(test_loader.load_test_file(path))

  let results = run_test_suite(suite, config, impl)

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
        TestFailed(_, _, _) -> True
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

/// Run a test suite against an implementation
pub fn run_test_suite(
  suite: TestSuite,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> List(TestResult) {
  suite.tests
  |> list.map(fn(tc) { run_single_test(tc, config, impl) })
}

/// Run a single test case
pub fn run_single_test(
  tc: TestCase,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> TestResult {
  // Check if test case is compatible with implementation
  case test_filter.get_skip_reason(config, tc) {
    Error(reason) -> TestSkipped(tc.name, reason)
    Ok(Nil) -> execute_test(tc, impl)
  }
}

/// Execute a test that passed compatibility checks
fn execute_test(tc: TestCase, impl: CclImplementation) -> TestResult {
  let input = case tc.inputs {
    [first, ..] -> first
    [] -> ""
  }

  case tc.validation {
    "parse" -> run_parse_test(tc.name, input, tc.expected, impl)
    "print" -> run_print_test(tc.name, input, tc.expected, impl)
    "build_hierarchy" -> run_hierarchy_test(tc.name, input, tc.expected, impl)
    "get_string" ->
      run_get_string_test(tc.name, input, tc.path, tc.expected, impl)
    "get_int" -> run_get_int_test(tc.name, input, tc.path, tc.expected, impl)
    "get_bool" -> run_get_bool_test(tc.name, input, tc.path, tc.expected, impl)
    "get_float" ->
      run_get_float_test(tc.name, input, tc.path, tc.expected, impl)
    "get_list" -> run_get_list_test(tc.name, input, tc.path, tc.expected, impl)
    other -> TestFailed(tc.name, "Unknown validation: " <> other, 0)
  }
}

/// Run a parse test
fn run_parse_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let expected_list =
            expected_entries
            |> list.map(fn(e) { Entry(e.key, e.value) })
          case entries == expected_list {
            True -> TestPassed(name, count)
            False -> {
              let expected_tuples =
                expected_list |> list.map(fn(e) { #(e.key, e.value) })
              let actual_tuples =
                entries |> list.map(fn(e) { #(e.key, e.value) })
              let default_theme = theme.default()
              TestFailed(
                name,
                "Entries mismatch:\n  expected:\n"
                  <> render_entries.tuples_to_ansi(
                  expected_tuples,
                  default_theme,
                )
                  <> "\n  actual:\n"
                  <> render_entries.tuples_to_ansi(actual_tuples, default_theme),
                count,
              )
            }
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case impl.parse(input) {
        Ok(_) -> TestFailed(name, "Expected error but got success", count)
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for parse test", 0)
  }
}

/// Run a print test
fn run_print_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let printed = impl.print(entries)
          case printed == expected_value {
            True -> TestPassed(name, count)
            False -> {
              let default_theme = theme.default()
              TestFailed(
                name,
                "Print mismatch:\n  expected: "
                  <> render_value.to_ansi(expected_value, default_theme)
                  <> "\n  actual: "
                  <> render_value.to_ansi(printed, default_theme),
                count,
              )
            }
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for print test", 0)
  }
}

/// Run a hierarchy test
fn run_hierarchy_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedObject(count, expected_obj) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case compare_objects(obj, expected_obj) {
            True -> TestPassed(name, count)
            False ->
              TestFailed(
                name,
                "Object mismatch:\n  expected: "
                  <> format_expected_object(expected_obj)
                  <> "\n  actual: "
                  <> format_ccl(obj),
                count,
              )
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for hierarchy test", 0)
  }
}

/// Run a get_string test
fn run_get_string_test(
  name: String,
  input: String,
  path: option.Option(List(String)),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  let key_path = option.unwrap(path, [])

  case expected {
    ExpectedValue(count, expected_value) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_string(obj, key_path) {
            Ok(value) -> {
              case value == expected_value {
                True -> TestPassed(name, count)
                False -> {
                  let default_theme = theme.default()
                  TestFailed(
                    name,
                    "Value mismatch: expected "
                      <> render_value.to_ansi(expected_value, default_theme)
                      <> ", got "
                      <> render_value.to_ansi(value, default_theme),
                    count,
                  )
                }
              }
            }
            Error(e) -> TestFailed(name, "get_string error: " <> e, count)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_string(obj, key_path) {
            Ok(_) -> TestFailed(name, "Expected error but got success", count)
            Error(_) -> TestPassed(name, count)
          }
        }
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for get_string test", 0)
  }
}

/// Run a get_int test
fn run_get_int_test(
  name: String,
  input: String,
  path: option.Option(List(String)),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  let key_path = option.unwrap(path, [])

  case expected {
    ExpectedInt(count, expected_value) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_int(obj, key_path) {
            Ok(value) -> {
              case value == expected_value {
                True -> TestPassed(name, count)
                False ->
                  TestFailed(
                    name,
                    "Value mismatch: expected "
                      <> int.to_string(expected_value)
                      <> ", got "
                      <> int.to_string(value),
                    count,
                  )
              }
            }
            Error(e) -> TestFailed(name, "get_int error: " <> e, count)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_int(obj, key_path) {
            Ok(_) -> TestFailed(name, "Expected error but got success", count)
            Error(_) -> TestPassed(name, count)
          }
        }
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for get_int test", 0)
  }
}

/// Run a get_bool test
fn run_get_bool_test(
  name: String,
  input: String,
  path: option.Option(List(String)),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  let key_path = option.unwrap(path, [])

  case expected {
    ExpectedBool(count, expected_value) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_bool(obj, key_path) {
            Ok(value) -> {
              case value == expected_value {
                True -> TestPassed(name, count)
                False ->
                  TestFailed(
                    name,
                    "Value mismatch: expected "
                      <> string.inspect(expected_value)
                      <> ", got "
                      <> string.inspect(value),
                    count,
                  )
              }
            }
            Error(e) -> TestFailed(name, "get_bool error: " <> e, count)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_bool(obj, key_path) {
            Ok(_) -> TestFailed(name, "Expected error but got success", count)
            Error(_) -> TestPassed(name, count)
          }
        }
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for get_bool test", 0)
  }
}

/// Run a get_float test
fn run_get_float_test(
  name: String,
  input: String,
  path: option.Option(List(String)),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  let key_path = option.unwrap(path, [])

  case expected {
    ExpectedFloat(count, expected_value) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_float(obj, key_path) {
            Ok(value) -> {
              // Use approximate comparison for floats
              let diff = float_abs(value -. expected_value)
              case diff <. 0.0001 {
                True -> TestPassed(name, count)
                False ->
                  TestFailed(
                    name,
                    "Value mismatch: expected "
                      <> string.inspect(expected_value)
                      <> ", got "
                      <> string.inspect(value),
                    count,
                  )
              }
            }
            Error(e) -> TestFailed(name, "get_float error: " <> e, count)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_float(obj, key_path) {
            Ok(_) -> TestFailed(name, "Expected error but got success", count)
            Error(_) -> TestPassed(name, count)
          }
        }
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for get_float test", 0)
  }
}

fn float_abs(x: Float) -> Float {
  case x <. 0.0 {
    True -> 0.0 -. x
    False -> x
  }
}

/// Run a get_list test
fn run_get_list_test(
  name: String,
  input: String,
  path: option.Option(List(String)),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  let key_path = option.unwrap(path, [])

  case expected {
    ExpectedList(count, expected_list) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_list(obj, key_path) {
            Ok(value) -> {
              case value == expected_list {
                True -> TestPassed(name, count)
                False ->
                  TestFailed(
                    name,
                    "List mismatch: expected "
                      <> string.inspect(expected_list)
                      <> ", got "
                      <> string.inspect(value),
                    count,
                  )
              }
            }
            Error(e) -> TestFailed(name, "get_list error: " <> e, count)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let obj = impl.build_hierarchy(entries)
          case impl.get_list(obj, key_path) {
            Ok(_) -> TestFailed(name, "Expected error but got success", count)
            Error(_) -> TestPassed(name, count)
          }
        }
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for get_list test", 0)
  }
}

/// Compare CCL object with expected object
fn compare_objects(actual: CCL, expected: Dict(String, ExpectedNode)) -> Bool {
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
fn compare_values(actual: CCLValue, expected: ExpectedNode) -> Bool {
  case actual, expected {
    CclString(s), NodeString(es) -> s == es
    CclList(l), NodeList(el) -> l == el
    CclObject(obj), NodeObject(eobj) -> compare_objects(obj, eobj)
    _, _ -> False
  }
}

/// Format expected object for error messages
fn format_expected_object(obj: Dict(String, ExpectedNode)) -> String {
  obj
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(k, v) = pair
    k <> ": " <> format_expected_node(v)
  })
  |> string.join(", ")
  |> fn(s) { "{" <> s <> "}" }
}

fn format_expected_node(node: ExpectedNode) -> String {
  case node {
    NodeString(s) -> string.inspect(s)
    NodeList(l) -> string.inspect(l)
    NodeObject(obj) -> format_expected_object(obj)
  }
}

/// Format CCL object for error messages
fn format_ccl(obj: CCL) -> String {
  obj
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(k, v) = pair
    k <> ": " <> format_ccl_value(v)
  })
  |> string.join(", ")
  |> fn(s) { "{" <> s <> "}" }
}

fn format_ccl_value(value: CCLValue) -> String {
  case value {
    CclString(s) -> string.inspect(s)
    CclList(l) -> string.inspect(l)
    CclObject(obj) -> format_ccl(obj)
  }
}

/// Print test results summary using birch
pub fn print_results(results: List(TestSuiteResult)) -> Nil {
  let total_passed =
    results
    |> list.map(fn(r) { r.passed })
    |> list.fold(0, fn(acc, n) { acc + n })

  let total_failed =
    results
    |> list.map(fn(r) { r.failed })
    |> list.fold(0, fn(acc, n) { acc + n })

  let total_skipped =
    results
    |> list.map(fn(r) { r.skipped })
    |> list.fold(0, fn(acc, n) { acc + n })

  let total =
    results
    |> list.map(fn(r) { r.total })
    |> list.fold(0, fn(acc, n) { acc + n })

  // Print per-file summaries
  list.each(results, fn(r) {
    birch.info_m("Suite complete", [
      #("file", r.file),
      #("passed", int.to_string(r.passed)),
      #("failed", int.to_string(r.failed)),
      #("skipped", int.to_string(r.skipped)),
    ])

    // Print failures
    list.each(r.results, fn(test_result) {
      case test_result {
        TestFailed(name, reason, _) -> {
          birch.error_m("Test failed", [#("test", name), #("reason", reason)])
        }
        _ -> Nil
      }
    })
  })

  // Print overall summary
  birch.info_m("All tests complete", [
    #("total", int.to_string(total)),
    #("passed", int.to_string(total_passed)),
    #("failed", int.to_string(total_failed)),
    #("skipped", int.to_string(total_skipped)),
  ])

  Nil
}
