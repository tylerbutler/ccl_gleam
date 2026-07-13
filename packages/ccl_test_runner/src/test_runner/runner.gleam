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
import gleam/float
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

/// Derive ParseOptions from a test case's behaviours list.
fn parse_options_for_test(tc: TestCase) -> ccl_types.ParseOptions {
  let line_endings = case
    list.contains(tc.behaviours, "crlf_preserve_literal")
  {
    True -> ccl_types.PreserveLiteral
    False -> ccl_types.NormalizeToLf
  }
  let tab_handling = case list.contains(tc.behaviours, "tabs_as_content") {
    True -> ccl_types.TabsAsContent
    False -> ccl_types.TabsAsWhitespace
  }
  let continuation_baseline = case
    list.contains(tc.behaviours, "toplevel_indent_preserve")
  {
    True -> ccl_types.IndentPreserve
    False -> ccl_types.IndentStrip
  }
  let delimiter_strategy = case
    list.contains(tc.behaviours, "delimiter_prefer_spaced")
  {
    True -> ccl_types.DelimiterPreferSpaced
    False -> ccl_types.DelimiterFirstEquals
  }
  ccl_types.ParseOptions(
    line_endings:,
    tab_handling:,
    continuation_baseline:,
    delimiter_strategy:,
  )
}

/// Derive AccessOptions from a test case's behaviours list.
fn access_options_for_test(tc: TestCase) -> ccl_types.AccessOptions {
  let boolean_parsing = case list.contains(tc.behaviours, "boolean_lenient") {
    True -> ccl_types.BooleanLenient
    False -> ccl_types.BooleanStrict
  }
  let list_coercion = case
    list.contains(tc.behaviours, "list_coercion_enabled")
  {
    True -> ccl_types.CoercionEnabled
    False -> ccl_types.CoercionDisabled
  }
  ccl_types.AccessOptions(boolean_parsing:, list_coercion:)
}

/// Derive BuildOptions from a test case's behaviours list.
fn build_options_for_test(tc: TestCase) -> ccl_types.BuildOptions {
  let array_order = case
    list.contains(tc.behaviours, "array_order_lexicographic")
  {
    True -> ccl_types.LexicographicOrder
    False -> ccl_types.InsertionOrder
  }
  ccl_types.BuildOptions(array_order:)
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
pub fn run_single_test(
  tc: TestCase,
  config: ImplementationConfig,
) -> TestResult {
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

  let parse_opts = parse_options_for_test(tc)
  let access_opts = access_options_for_test(tc)
  let build_opts = build_options_for_test(tc)

  case tc.validation {
    "parse" ->
      run_parse_test(tc.name, input, tc.expected, parser.parse_with, parse_opts)
    "parse_indented" ->
      run_parse_test(
        tc.name,
        input,
        tc.expected,
        parser.parse_indented_with,
        parse_opts,
      )
    "print" -> run_print_test(tc.name, input, tc.expected, parse_opts)
    "build_hierarchy" ->
      run_hierarchy_test(tc.name, input, tc.expected, parse_opts, build_opts)
    "get_string" ->
      run_access_test(
        tc,
        input,
        parse_opts,
        build_opts,
        access.get_string,
        fn(expected) {
          case expected {
            ExpectedValue(count, value) -> Ok(#(count, value))
            _ -> Error(Nil)
          }
        },
        fn(a, b) { a == b },
        string.inspect,
      )
    "get_int" ->
      run_access_test(
        tc,
        input,
        parse_opts,
        build_opts,
        access.get_int,
        fn(expected) {
          case expected {
            ExpectedInt(count, value) -> Ok(#(count, value))
            _ -> Error(Nil)
          }
        },
        fn(a, b) { a == b },
        int.to_string,
      )
    "get_bool" ->
      run_access_test(
        tc,
        input,
        parse_opts,
        build_opts,
        fn(obj, path) { access.get_bool_with(obj, path, access_opts) },
        fn(expected) {
          case expected {
            ExpectedBool(count, value) | ExpectedBoolean(count, value) ->
              Ok(#(count, value))
            _ -> Error(Nil)
          }
        },
        fn(a, b) { a == b },
        string.inspect,
      )
    "get_float" ->
      run_access_test(
        tc,
        input,
        parse_opts,
        build_opts,
        access.get_float,
        fn(expected) {
          case expected {
            ExpectedFloat(count, value) -> Ok(#(count, value))
            ExpectedInt(count, value) -> Ok(#(count, int.to_float(value)))
            _ -> Error(Nil)
          }
        },
        fn(a, b) { float.absolute_value(a -. b) <. 0.0001 },
        string.inspect,
      )
    "get_list" ->
      run_access_test(
        tc,
        input,
        parse_opts,
        build_opts,
        fn(obj, path) { access.get_list_with(obj, path, access_opts) },
        fn(expected) {
          case expected {
            ExpectedList(count, value) -> Ok(#(count, value))
            _ -> Error(Nil)
          }
        },
        fn(a, b) { a == b },
        string.inspect,
      )
    "filter" ->
      run_filter_test(tc.name, input, tc.expected, tc.predicate, parse_opts)
    "round_trip" -> run_round_trip_test(tc.name, input, tc.expected, parse_opts)
    "canonical_format" ->
      run_canonical_format_test(
        tc.name,
        input,
        tc.expected,
        parse_opts,
        build_opts,
      )
    other -> error_fail(tc.name, "Unknown validation: " <> other, 0)
  }
}

// --- Parse tests (shared by parse and parse_indented) ---

fn run_parse_test(
  name: String,
  input: String,
  expected: Expected,
  parse: fn(String, ccl_types.ParseOptions) ->
    Result(List(ccl_types.Entry), String),
  parse_opts: ccl_types.ParseOptions,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case parse(input, parse_opts) {
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
      case parse(input, parse_opts) {
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
      case parse(input, parse_opts) {
        Ok(_) -> TestPassed(name, count)
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for parse test", 0)
  }
}

// --- Typed access tests (shared by all get_* validations) ---

/// Shared scaffold for get_* validations: extract the typed expected value,
/// parse and build, run the accessor, and compare. The ExpectedError and
/// ExpectedCountOnly arms are identical for every type.
fn run_access_test(
  tc: TestCase,
  input: String,
  parse_opts: ccl_types.ParseOptions,
  build_opts: ccl_types.BuildOptions,
  accessor: fn(ccl_types.CCL, List(String)) -> Result(t, String),
  extract_expected: fn(Expected) -> Result(#(Int, t), Nil),
  equals: fn(t, t) -> Bool,
  show: fn(t) -> String,
) -> TestResult {
  let name = tc.name
  let path = resolve_path(tc)
  case extract_expected(tc.expected) {
    Ok(#(count, expected_value)) ->
      case parse_and_build_with(input, parse_opts, build_opts) {
        Ok(obj) ->
          case accessor(obj, path) {
            Ok(value) ->
              case equals(value, expected_value) {
                True -> TestPassed(name, count)
                False ->
                  mismatch(
                    name,
                    "Value mismatch",
                    show(value),
                    show(expected_value),
                    count,
                  )
              }
            Error(e) ->
              error_fail(name, tc.validation <> " error: " <> e, count)
          }
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    Error(Nil) ->
      case tc.expected {
        ExpectedError(count, True) ->
          run_expected_error_test_with(
            name,
            input,
            path,
            count,
            parse_opts,
            build_opts,
            fn(obj, p) { accessor(obj, p) |> result.map(show) },
          )
        // Count-only: accept either success or error
        ExpectedCountOnly(count) -> TestPassed(name, count)
        _ ->
          error_fail(
            name,
            "Invalid expected type for " <> tc.validation <> " test",
            0,
          )
      }
  }
}

// --- Filter tests ---

fn run_filter_test(
  name: String,
  input: String,
  expected: Expected,
  predicate: option.Option(types.Predicate),
  parse_opts: ccl_types.ParseOptions,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case parser.parse_with(input, parse_opts) {
        Ok(entries) -> {
          let filtered =
            entries
            |> list.filter(fn(e) { e.key != "/" })
            |> apply_predicate(predicate)
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
      case parser.parse_with(input, parse_opts) {
        Ok(entries) -> {
          let filtered =
            entries
            |> list.filter(fn(e) { e.key != "/" })
            |> apply_predicate(predicate)
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

/// Keep only entries that satisfy the filter predicate.
/// With no predicate, all entries are kept.
fn apply_predicate(
  entries: List(ccl_types.Entry),
  predicate: option.Option(types.Predicate),
) -> List(ccl_types.Entry) {
  case predicate {
    option.None -> entries
    option.Some(types.Predicate(field, op, target)) ->
      list.filter(entries, fn(e) {
        let actual = case field {
          "value" -> e.value
          _ -> e.key
        }
        case op {
          "!=" -> actual != target
          _ -> actual == target
        }
      })
  }
}

// --- Print tests ---

fn run_print_test(
  name: String,
  input: String,
  expected: Expected,
  parse_opts: ccl_types.ParseOptions,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      case parser.parse_with(input, parse_opts) {
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
  parse_opts: ccl_types.ParseOptions,
) -> TestResult {
  let count = get_expected_count(expected)
  case parser.parse_with(input, parse_opts) {
    Ok(entries) -> {
      let printed = format.print(entries)
      case parser.parse_with(printed, parse_opts) {
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
  parse_opts: ccl_types.ParseOptions,
  build_opts: ccl_types.BuildOptions,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      case parser.parse_with(input, parse_opts) {
        Ok(entries) -> {
          let ccl =
            hierarchy.build_hierarchy_with(entries, build_opts, parse_opts)
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
  parse_opts: ccl_types.ParseOptions,
  build_opts: ccl_types.BuildOptions,
) -> TestResult {
  case expected {
    ExpectedObject(count, expected_obj) -> {
      case parser.parse_with(input, parse_opts) {
        Ok(entries) -> {
          let obj =
            hierarchy.build_hierarchy_with(entries, build_opts, parse_opts)
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
      case parse_and_build_with(input, parse_opts, build_opts) {
        Ok(_) -> TestPassed(name, count)
        Error(e) -> error_fail(name, "Parse error: " <> e, count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for hierarchy test", 0)
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

/// Parse input and build hierarchy in one step with options.
fn parse_and_build_with(
  input: String,
  parse_opts: ccl_types.ParseOptions,
  build_opts: ccl_types.BuildOptions,
) -> Result(ccl_types.CCL, String) {
  parser.parse_with(input, parse_opts)
  |> result.map(hierarchy.build_hierarchy_with(_, build_opts, parse_opts))
}

/// Run a test that expects an error result, with options.
fn run_expected_error_test_with(
  name: String,
  input: String,
  path: List(String),
  count: Int,
  parse_opts: ccl_types.ParseOptions,
  build_opts: ccl_types.BuildOptions,
  accessor: fn(ccl_types.CCL, List(String)) -> Result(String, String),
) -> TestResult {
  case parse_and_build_with(input, parse_opts, build_opts) {
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
  case items {
    [] -> "[]"
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
  let total_passed = int.sum(list.map(results, fn(r) { r.passed }))
  let total_failed = int.sum(list.map(results, fn(r) { r.failed }))
  let total_skipped = int.sum(list.map(results, fn(r) { r.skipped }))
  let total = int.sum(list.map(results, fn(r) { r.total }))

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
