/// Test runner that executes tests against a CCL implementation.
import birch
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import render/diff
import render/list as render_list
import render/object as render_object
import render/report
import render/theme
import render/typed
import render/value as render_value
import test_filter
import test_loader
import test_types.{
  type Expected, type ExpectedNode, type ImplementationConfig, type TestCase,
  type TestCaseResult, type TestResult, type TestSuite, type TestSuiteResult,
  ExpectedBool, ExpectedCountOnly, ExpectedEntries, ExpectedError,
  ExpectedFloat, ExpectedInt, ExpectedList, ExpectedObject, ExpectedValue,
  NodeList, NodeObject, NodeString, TestCaseResult, TestFailed, TestPassed,
  TestSkipped, TestSuiteResult,
}

/// Type alias for CCL entry.
pub type Entry {
  Entry(key: String, value: String)
}

/// Type alias for CCL nested object.
pub type CCL =
  Dict(String, CCLValue)

/// CCL value types.
pub type CCLValue {
  CclString(String)
  CclList(List(String))
  CclObject(CCL)
}

/// CCL implementation interface - functions that implementations must provide.
pub type CclImplementation {
  CclImplementation(
    parse: fn(String) -> Result(List(Entry), String),
    parse_indented: fn(String) -> Result(List(Entry), String),
    print: fn(List(Entry)) -> String,
    filter: fn(List(Entry)) -> List(Entry),
    compose: fn(List(Entry), List(Entry)) -> List(Entry),
    build_hierarchy: fn(List(Entry)) -> CCL,
    get_string: fn(CCL, List(String)) -> Result(String, String),
    get_int: fn(CCL, List(String)) -> Result(Int, String),
    get_bool: fn(CCL, List(String)) -> Result(Bool, String),
    get_float: fn(CCL, List(String)) -> Result(Float, String),
    get_list: fn(CCL, List(String)) -> Result(List(String), String),
  )
}

// ============================================================================
// Public API
// ============================================================================

/// Run all tests from a directory against an implementation.
pub fn run_test_directory(
  dir: String,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> Result(List(TestSuiteResult), String) {
  use files <- result.try(test_loader.list_test_files(dir))

  birch.debug_m("Found test files", [
    #("count", int.to_string(list.length(files))),
  ])

  files
  |> list.map(fn(file) { run_test_file(file, config, impl) })
  |> result.all
}

/// Run all tests from a single file.
pub fn run_test_file(
  path: String,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> Result(TestSuiteResult, String) {
  birch.debug_m("Loading test file", [#("path", path)])
  use suite <- result.try(test_loader.load_test_file(path))

  let results = run_test_suite(suite, config, impl)
  let #(passed, failed, skipped) =
    results |> list.map(fn(r) { r.result }) |> count_results

  Ok(TestSuiteResult(
    file: path,
    total: list.length(results),
    passed: passed,
    failed: failed,
    skipped: skipped,
    results: results,
  ))
}

/// Run a test suite against an implementation.
pub fn run_test_suite(
  suite: TestSuite,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> List(TestCaseResult) {
  suite.tests
  |> list.map(fn(tc) { run_single_test(tc, config, impl) })
}

/// Run a single test case.
pub fn run_single_test(
  tc: TestCase,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> TestCaseResult {
  let result = case test_filter.get_skip_reason(config, tc) {
    Error(reason) -> TestSkipped(tc.name, reason)
    Ok(Nil) -> execute_test(tc, impl)
  }
  TestCaseResult(test_case: tc, result: result)
}

/// Print test results report.
pub fn print_results(
  results: List(TestSuiteResult),
  config: test_types.ImplementationConfig,
  test_dir: String,
  grouping: test_types.FailureGrouping,
) -> Nil {
  report.print_report_grouped(results, config, test_dir, grouping)
}

// ============================================================================
// Test dispatch
// ============================================================================

fn execute_test(tc: TestCase, impl: CclImplementation) -> TestResult {
  let input = case tc.inputs {
    [first, ..] -> first
    [] -> ""
  }

  case tc.validation {
    "parse" -> run_parse_variant(tc.name, input, tc.expected, impl.parse)
    "parse_indented" ->
      run_parse_variant(tc.name, input, tc.expected, impl.parse_indented)
    "print" ->
      run_print_variant(tc.name, input, tc.expected, impl, "Print mismatch")
    "canonical_format" ->
      run_print_variant(
        tc.name,
        input,
        tc.expected,
        impl,
        "Canonical format mismatch",
      )
    "round_trip" -> run_round_trip_test(tc.name, input, tc.expected, impl)
    "filter" -> run_filter_test(tc.name, input, tc.expected, impl)
    "compose_associative" ->
      run_compose_associative_test(tc.name, tc.inputs, tc.expected, impl)
    "identity_left" ->
      run_identity_test(tc.name, tc.inputs, tc.expected, impl, IdentityLeft)
    "identity_right" ->
      run_identity_test(tc.name, tc.inputs, tc.expected, impl, IdentityRight)
    "build_hierarchy" -> run_hierarchy_test(tc.name, input, tc.expected, impl)
    "get_string" ->
      run_typed_access_test(
        tc.name,
        input,
        tc.path,
        tc.expected,
        impl,
        GetString,
      )
    "get_int" ->
      run_typed_access_test(tc.name, input, tc.path, tc.expected, impl, GetInt)
    "get_bool" ->
      run_typed_access_test(tc.name, input, tc.path, tc.expected, impl, GetBool)
    "get_float" ->
      run_typed_access_test(
        tc.name,
        input,
        tc.path,
        tc.expected,
        impl,
        GetFloat,
      )
    "get_list" ->
      run_typed_access_test(tc.name, input, tc.path, tc.expected, impl, GetList)
    other -> TestFailed(tc.name, "Unknown validation: " <> other, 0)
  }
}

// ============================================================================
// Shared helpers
// ============================================================================

/// Count passed/failed/skipped in a single pass.
fn count_results(results: List(TestResult)) -> #(Int, Int, Int) {
  list.fold(results, #(0, 0, 0), fn(acc, r) {
    let #(p, f, s) = acc
    case r {
      TestPassed(_, _) -> #(p + 1, f, s)
      TestFailed(_, _, _) -> #(p, f + 1, s)
      TestSkipped(_, _) -> #(p, f, s + 1)
    }
  })
}

/// Convert entries to tuples for diff display.
fn entries_to_tuples(entries: List(Entry)) -> List(#(String, String)) {
  entries |> list.map(fn(e) { #(e.key, e.value) })
}

/// Format an entries mismatch error.
fn entries_mismatch(
  label: String,
  expected: List(Entry),
  actual: List(Entry),
) -> String {
  let default_theme = theme.default()
  label
  <> ":\n"
  <> diff.entries_diff(
    entries_to_tuples(expected),
    entries_to_tuples(actual),
    default_theme,
  )
}

/// Convert test entries to runner entries.
fn test_entries_to_entries(
  test_entries: List(test_types.TestEntry),
) -> List(Entry) {
  test_entries |> list.map(fn(e) { Entry(e.key, e.value) })
}

// ============================================================================
// Parse tests (shared between parse and parse_indented)
// ============================================================================

fn run_parse_variant(
  name: String,
  input: String,
  expected: Expected,
  parse_fn: fn(String) -> Result(List(Entry), String),
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case parse_fn(input) {
        Ok(entries) -> {
          let expected_list = test_entries_to_entries(expected_entries)
          case entries == expected_list {
            True -> TestPassed(name, count)
            False ->
              TestFailed(
                name,
                entries_mismatch("Entries mismatch", expected_list, entries),
                count,
              )
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case parse_fn(input) {
        Ok(_) -> TestFailed(name, "Expected error but got success", count)
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for parse test", 0)
  }
}

// ============================================================================
// Print tests (shared between print and canonical_format)
// ============================================================================

fn run_print_variant(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
  error_label: String,
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
                error_label
                  <> ":\n"
                  <> diff.value_diff(expected_value, printed, default_theme),
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

// ============================================================================
// Round-trip test
// ============================================================================

fn run_round_trip_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  // Both ExpectedBool(_, True) and ExpectedValue(_, _) use the same logic
  let count = case expected {
    ExpectedBool(c, True) -> Ok(c)
    ExpectedValue(c, _) -> Ok(c)
    _ -> Error(Nil)
  }

  case count {
    Error(_) -> TestFailed(name, "Invalid expected type for round_trip test", 0)
    Ok(c) -> {
      case impl.parse(input) {
        Ok(parsed) -> {
          let printed = impl.print(parsed)
          case impl.parse(printed) {
            Ok(reparsed) -> {
              case parsed == reparsed {
                True -> TestPassed(name, c)
                False ->
                  TestFailed(
                    name,
                    entries_mismatch(
                      "Round-trip mismatch: parse(print(parse(x))) != parse(x)",
                      parsed,
                      reparsed,
                    ),
                    c,
                  )
              }
            }
            Error(e) -> TestFailed(name, "Re-parse error: " <> e, c)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, c)
      }
    }
  }
}

// ============================================================================
// Filter test
// ============================================================================

fn run_filter_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let filtered = impl.filter(entries)
          let expected_list = test_entries_to_entries(expected_entries)
          case filtered == expected_list {
            True -> TestPassed(name, count)
            False ->
              TestFailed(
                name,
                entries_mismatch("Filter mismatch", expected_list, filtered),
                count,
              )
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedCountOnly(count) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let _filtered = impl.filter(entries)
          TestPassed(name, count)
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for filter test", 0)
  }
}

// ============================================================================
// Compose tests
// ============================================================================

fn run_compose_associative_test(
  name: String,
  inputs: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedBool(count, True) -> {
      case inputs {
        [input_a, input_b, input_c] -> {
          case impl.parse(input_a), impl.parse(input_b), impl.parse(input_c) {
            Ok(a), Ok(b), Ok(c) -> {
              let left = impl.compose(impl.compose(a, b), c)
              let right = impl.compose(a, impl.compose(b, c))
              case left == right {
                True -> TestPassed(name, count)
                False ->
                  TestFailed(
                    name,
                    entries_mismatch(
                      "Compose not associative: (a·b)·c != a·(b·c)",
                      left,
                      right,
                    ),
                    count,
                  )
              }
            }
            _, _, _ ->
              TestFailed(name, "Parse error on one or more inputs", count)
          }
        }
        _ ->
          TestFailed(
            name,
            "compose_associative requires exactly 3 inputs, got "
              <> int.to_string(list.length(inputs)),
            0,
          )
      }
    }
    _ ->
      TestFailed(name, "Invalid expected type for compose_associative test", 0)
  }
}

/// Identity direction for compose identity tests.
type IdentityDir {
  IdentityLeft
  IdentityRight
}

fn run_identity_test(
  name: String,
  inputs: List(String),
  expected: Expected,
  impl: CclImplementation,
  dir: IdentityDir,
) -> TestResult {
  case expected {
    ExpectedBool(count, True) -> {
      case inputs {
        [input_first, input_second] -> {
          case impl.parse(input_first), impl.parse(input_second) {
            Ok(first), Ok(second) -> {
              // For left: compose(empty, x) == x → first=empty, second=x
              // For right: compose(x, empty) == x → first=x, second=empty
              let #(composed, x) = case dir {
                IdentityLeft -> #(impl.compose(first, second), second)
                IdentityRight -> #(impl.compose(first, second), first)
              }
              let label = case dir {
                IdentityLeft -> "Identity left failed: compose(empty, x) != x"
                IdentityRight -> "Identity right failed: compose(x, empty) != x"
              }
              case composed == x {
                True -> TestPassed(name, count)
                False ->
                  TestFailed(name, entries_mismatch(label, x, composed), count)
              }
            }
            _, _ -> TestFailed(name, "Parse error on one or more inputs", count)
          }
        }
        _ ->
          TestFailed(
            name,
            "identity test requires exactly 2 inputs, got "
              <> int.to_string(list.length(inputs)),
            0,
          )
      }
    }
    _ -> TestFailed(name, "Invalid expected type for identity test", 0)
  }
}

// ============================================================================
// Hierarchy test
// ============================================================================

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
            False -> {
              let default_theme = theme.default()
              let expected_lines =
                render_object.to_ansi(expected_obj, default_theme)
                |> string.split("\n")
              let actual_lines = format_ccl(obj) |> string.split("\n")
              TestFailed(
                name,
                "Object mismatch:\n"
                  <> diff.block_diff(expected_lines, actual_lines),
                count,
              )
            }
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for hierarchy test", 0)
  }
}

// ============================================================================
// Typed access tests (unified for get_string, get_int, get_bool, get_float, get_list)
// ============================================================================

/// Which typed accessor to use.
type TypedAccessor {
  GetString
  GetInt
  GetBool
  GetFloat
  GetList
}

fn run_typed_access_test(
  name: String,
  input: String,
  path: option.Option(List(String)),
  expected: Expected,
  impl: CclImplementation,
  accessor: TypedAccessor,
) -> TestResult {
  let key_path = option.unwrap(path, [])

  // Handle ExpectedError for all typed access tests uniformly
  case expected {
    ExpectedError(count, True) ->
      run_typed_access_error(name, input, key_path, count, impl, accessor)
    _ -> run_typed_access_value(name, input, key_path, expected, impl, accessor)
  }
}

/// Handle the ExpectedError case for any typed accessor.
fn run_typed_access_error(
  name: String,
  input: String,
  key_path: List(String),
  count: Int,
  impl: CclImplementation,
  accessor: TypedAccessor,
) -> TestResult {
  case impl.parse(input) {
    Ok(entries) -> {
      let obj = impl.build_hierarchy(entries)
      let result = case accessor {
        GetString -> impl.get_string(obj, key_path) |> result.map(fn(_) { Nil })
        GetInt -> impl.get_int(obj, key_path) |> result.map(fn(_) { Nil })
        GetBool -> impl.get_bool(obj, key_path) |> result.map(fn(_) { Nil })
        GetFloat -> impl.get_float(obj, key_path) |> result.map(fn(_) { Nil })
        GetList -> impl.get_list(obj, key_path) |> result.map(fn(_) { Nil })
      }
      case result {
        Ok(_) -> TestFailed(name, "Expected error but got success", count)
        Error(_) -> TestPassed(name, count)
      }
    }
    Error(_) -> TestPassed(name, count)
  }
}

/// Handle the value-comparison case for typed accessors.
fn run_typed_access_value(
  name: String,
  input: String,
  key_path: List(String),
  expected: Expected,
  impl: CclImplementation,
  accessor: TypedAccessor,
) -> TestResult {
  case impl.parse(input) {
    Ok(entries) -> {
      let obj = impl.build_hierarchy(entries)
      case accessor {
        GetString -> run_get_string_value(name, obj, key_path, expected, impl)
        GetInt -> run_get_int_value(name, obj, key_path, expected, impl)
        GetBool -> run_get_bool_value(name, obj, key_path, expected, impl)
        GetFloat -> run_get_float_value(name, obj, key_path, expected, impl)
        GetList -> run_get_list_value(name, obj, key_path, expected, impl)
      }
    }
    Error(e) -> TestFailed(name, "Parse error: " <> e, 0)
  }
}

fn run_get_string_value(
  name: String,
  obj: CCL,
  key_path: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) ->
      case impl.get_string(obj, key_path) {
        Ok(value) ->
          compare_or_fail(name, count, value == expected_value, fn() {
            let t = theme.default()
            diff.inline_diff(
              render_value.to_ansi(expected_value, t),
              render_value.to_ansi(value, t),
            )
          })
        Error(e) -> TestFailed(name, "get_string error: " <> e, count)
      }
    _ -> TestFailed(name, "Invalid expected type for get_string test", 0)
  }
}

fn run_get_int_value(
  name: String,
  obj: CCL,
  key_path: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedInt(count, expected_value) ->
      case impl.get_int(obj, key_path) {
        Ok(value) ->
          compare_or_fail(name, count, value == expected_value, fn() {
            let t = theme.default()
            diff.inline_diff(
              typed.int_to_ansi(expected_value, t),
              typed.int_to_ansi(value, t),
            )
          })
        Error(e) -> TestFailed(name, "get_int error: " <> e, count)
      }
    _ -> TestFailed(name, "Invalid expected type for get_int test", 0)
  }
}

fn run_get_bool_value(
  name: String,
  obj: CCL,
  key_path: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedBool(count, expected_value) ->
      case impl.get_bool(obj, key_path) {
        Ok(value) ->
          compare_or_fail(name, count, value == expected_value, fn() {
            let t = theme.default()
            diff.inline_diff(
              typed.bool_to_ansi(expected_value, t),
              typed.bool_to_ansi(value, t),
            )
          })
        Error(e) -> TestFailed(name, "get_bool error: " <> e, count)
      }
    _ -> TestFailed(name, "Invalid expected type for get_bool test", 0)
  }
}

fn run_get_float_value(
  name: String,
  obj: CCL,
  key_path: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedFloat(count, expected_value) ->
      case impl.get_float(obj, key_path) {
        Ok(value) -> {
          let close = float_abs(value -. expected_value) <. 0.0001
          compare_or_fail(name, count, close, fn() {
            let t = theme.default()
            diff.inline_diff(
              typed.float_to_ansi(expected_value, t),
              typed.float_to_ansi(value, t),
            )
          })
        }
        Error(e) -> TestFailed(name, "get_float error: " <> e, count)
      }
    _ -> TestFailed(name, "Invalid expected type for get_float test", 0)
  }
}

fn run_get_list_value(
  name: String,
  obj: CCL,
  key_path: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedList(count, expected_list) ->
      case impl.get_list(obj, key_path) {
        Ok(value) -> {
          case value == expected_list {
            True -> TestPassed(name, count)
            False -> {
              let t = theme.default()
              let expected_lines =
                render_list.to_ansi(expected_list, t) |> string.split("\n")
              let actual_lines =
                render_list.to_ansi(value, t) |> string.split("\n")
              TestFailed(
                name,
                "List mismatch:\n"
                  <> diff.block_diff(expected_lines, actual_lines),
                count,
              )
            }
          }
        }
        Error(e) -> TestFailed(name, "get_list error: " <> e, count)
      }
    _ -> TestFailed(name, "Invalid expected type for get_list test", 0)
  }
}

/// Helper: if equal return passed, otherwise call the diff_fn for error message.
fn compare_or_fail(
  name: String,
  count: Int,
  equal: Bool,
  diff_fn: fn() -> String,
) -> TestResult {
  case equal {
    True -> TestPassed(name, count)
    False -> TestFailed(name, "Value mismatch:\n" <> diff_fn(), count)
  }
}

fn float_abs(x: Float) -> Float {
  case x <. 0.0 {
    True -> 0.0 -. x
    False -> x
  }
}

// ============================================================================
// Object comparison
// ============================================================================

fn compare_objects(actual: CCL, expected: Dict(String, ExpectedNode)) -> Bool {
  let actual_keys = dict.keys(actual) |> list.sort(string.compare)
  let expected_keys = dict.keys(expected) |> list.sort(string.compare)

  case actual_keys == expected_keys {
    False -> False
    True ->
      list.all(actual_keys, fn(key) {
        case dict.get(actual, key), dict.get(expected, key) {
          Ok(actual_val), Ok(expected_val) ->
            compare_values(actual_val, expected_val)
          _, _ -> False
        }
      })
  }
}

fn compare_values(actual: CCLValue, expected: ExpectedNode) -> Bool {
  case actual, expected {
    CclString(s), NodeString(es) -> s == es
    CclList(l), NodeList(el) -> l == el
    CclObject(obj), NodeObject(eobj) -> compare_objects(obj, eobj)
    _, _ -> False
  }
}

/// Format CCL object for error messages.
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
