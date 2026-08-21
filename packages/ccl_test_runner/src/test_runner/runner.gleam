/// Test runner that executes tests against the CCL implementation directly.
///
/// Everything goes through the public `ccl` module, so the runner exercises the
/// same surface published to library users rather than the internal modules.
import birch
import ccl
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

/// Derive the CCL options for a test case from its behaviours list.
///
/// The public API folds parse, access, and build settings into one opaque
/// `Options`, so a test case's behaviours map onto a single builder chain.
fn options_for_test(tc: TestCase) -> ccl.Options {
  let has = fn(behaviour) { list.contains(tc.behaviours, behaviour) }
  let line_endings = case has("crlf_preserve_literal") {
    True -> ccl.PreserveCrlf
    False -> ccl.NormalizeCrlf
  }
  let tabs = case has("tabs_as_content") {
    True -> ccl.TabsAsContent
    False -> ccl.TabsAsWhitespace
  }
  let baseline = case has("toplevel_indent_preserve") {
    True -> ccl.PreserveToplevelIndent
    False -> ccl.StripToplevelIndent
  }
  let delimiter = case has("delimiter_prefer_spaced") {
    True -> ccl.PreferSpaced
    False -> ccl.FirstEquals
  }
  let booleans = case has("boolean_lenient") {
    True -> ccl.BooleanLenient
    False -> ccl.BooleanStrict
  }
  let coercion = case has("list_coercion_enabled") {
    True -> ccl.CoercionEnabled
    False -> ccl.CoercionDisabled
  }
  let order = case has("array_order_lexicographic") {
    True -> ccl.LexicographicOrder
    False -> ccl.InsertionOrder
  }

  ccl.default_options()
  |> ccl.with_line_endings(line_endings)
  |> ccl.with_tabs(tabs)
  |> ccl.with_baseline(baseline)
  |> ccl.with_delimiter(delimiter)
  |> ccl.with_booleans(booleans)
  |> ccl.with_list_coercion(coercion)
  |> ccl.with_list_order(order)
}

/// Render a parse error for a failure message.
fn describe_parse_error(error: ccl.ParseError) -> String {
  string.inspect(error)
}

/// Render a typed-read error for a failure message.
fn describe_get_error(error: ccl.GetError) -> String {
  string.inspect(error)
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

  let opts = options_for_test(tc)

  case tc.validation {
    "parse" -> run_parse_test(tc.name, input, tc.expected, ccl.parse_with, opts)
    "parse_indented" ->
      run_parse_test(tc.name, input, tc.expected, ccl.parse_indented_with, opts)
    "print" -> run_print_test(tc.name, input, tc.expected, opts)
    "build_hierarchy" -> run_hierarchy_test(tc.name, input, tc.expected, opts)
    "build_model" -> run_build_model_test(tc.name, input, tc.expected, opts)
    "get_string" ->
      run_access_test(
        tc,
        input,
        opts,
        ccl.get_string,
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
        opts,
        ccl.get_int,
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
        opts,
        ccl.get_bool,
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
        opts,
        ccl.get_float,
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
        opts,
        ccl.get_list,
        fn(expected) {
          case expected {
            ExpectedList(count, value) -> Ok(#(count, value))
            _ -> Error(Nil)
          }
        },
        fn(a, b) { a == b },
        string.inspect,
      )
    "filter" -> run_filter_test(tc.name, input, tc.expected, tc.predicate, opts)
    "round_trip" -> run_round_trip_test(tc.name, input, tc.expected, opts)
    "canonical_format" ->
      run_canonical_format_test(tc.name, input, tc.expected, opts)
    other -> error_fail(tc.name, "Unknown validation: " <> other, 0)
  }
}

// --- Parse tests (shared by parse and parse_indented) ---

fn run_parse_test(
  name: String,
  input: String,
  expected: Expected,
  parse: fn(String, ccl.Options) -> Result(ccl.Document, ccl.ParseError),
  opts: ccl.Options,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case parse(input, opts) {
        Ok(doc) -> {
          let entries = ccl.entries(doc)
          let expected_list =
            expected_entries
            |> list.map(fn(e) { ccl.Entry(e.key, e.value) })
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
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    }
    ExpectedError(count, True) -> {
      case parse(input, opts) {
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
      case parse(input, opts) {
        Ok(_) -> TestPassed(name, count)
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
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
  opts: ccl.Options,
  accessor: fn(ccl.Document, List(String)) -> Result(t, ccl.GetError),
  extract_expected: fn(Expected) -> Result(#(Int, t), Nil),
  equals: fn(t, t) -> Bool,
  show: fn(t) -> String,
) -> TestResult {
  let name = tc.name
  let path = resolve_path(tc)
  case extract_expected(tc.expected) {
    Ok(#(count, expected_value)) ->
      case ccl.parse_with(input, opts) {
        Ok(doc) ->
          case accessor(doc, path) {
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
              error_fail(
                name,
                tc.validation <> " error: " <> describe_get_error(e),
                count,
              )
          }
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    Error(Nil) ->
      case tc.expected {
        ExpectedError(count, True) ->
          run_expected_error_test_with(
            name,
            input,
            path,
            count,
            opts,
            fn(doc, p) { accessor(doc, p) |> result.map(show) },
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
  opts: ccl.Options,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case ccl.parse_with(input, opts) {
        Ok(doc) -> {
          let filtered = filtered_entries(doc, predicate)
          let expected_list =
            expected_entries
            |> list.map(fn(e) { ccl.Entry(e.key, e.value) })
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
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    }
    ExpectedCountOnly(count) -> {
      case ccl.parse_with(input, opts) {
        Ok(doc) -> {
          let filtered = filtered_entries(doc, predicate)
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
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for filter test", 0)
  }
}

/// Drop comment entries, then keep only those satisfying the predicate.
fn filtered_entries(
  doc: ccl.Document,
  predicate: option.Option(types.Predicate),
) -> List(ccl.Entry) {
  ccl.entries(doc)
  |> list.filter(fn(e) { e.key != "/" })
  |> apply_predicate(predicate)
}

/// Keep only entries that satisfy the filter predicate.
/// With no predicate, all entries are kept.
fn apply_predicate(
  entries: List(ccl.Entry),
  predicate: option.Option(types.Predicate),
) -> List(ccl.Entry) {
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
  opts: ccl.Options,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      case ccl.parse_with(input, opts) {
        Ok(doc) -> {
          let printed = ccl.print(ccl.entries(doc))
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
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
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
  opts: ccl.Options,
) -> TestResult {
  let count = get_expected_count(expected)
  case ccl.parse_with(input, opts) {
    Ok(doc) -> {
      let entries = ccl.entries(doc)
      case ccl.parse_with(ccl.print(entries), opts) {
        Ok(reparsed) -> {
          let re_entries = ccl.entries(reparsed)
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
        Error(e) ->
          error_fail(
            name,
            "Round trip re-parse error: " <> describe_parse_error(e),
            count,
          )
      }
    }
    Error(e) ->
      error_fail(name, "Parse error: " <> describe_parse_error(e), count)
  }
}

// --- Canonical format tests ---

fn run_canonical_format_test(
  name: String,
  input: String,
  expected: Expected,
  opts: ccl.Options,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      // Structural grouping always uses the auto-detected baseline (like
      // `parse_indented`), regardless of toplevel_indent_strip/preserve —
      // otherwise a pre-indented top-level document collapses into one
      // entry instead of forming siblings. `toplevel_indent_preserve` only
      // affects the render offset, which `to_canonical_string` derives from
      // the document's own options.
      case ccl.parse_indented_with(input, opts) {
        Ok(doc) -> {
          let formatted = ccl.to_canonical_string(doc)
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
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
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
  opts: ccl.Options,
) -> TestResult {
  case expected {
    ExpectedObject(count, expected_obj) -> {
      case ccl.parse_with(input, opts) {
        Ok(doc) -> {
          let pairs = root_pairs(doc)
          case compare_objects(pairs, expected_obj) {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Object mismatch",
                format_ccl(pairs),
                format_expected_object(expected_obj),
                count,
              )
          }
        }
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    }
    ExpectedCountOnly(count) -> {
      case ccl.parse_with(input, opts) {
        Ok(doc) -> {
          // Force the projection so a build that diverges still fails here
          // rather than being skipped by the lazy read.
          let _ = root_pairs(doc)
          TestPassed(name, count)
        }
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for hierarchy test", 0)
  }
}

/// The document's top-level entries as an ordered association list.
fn root_pairs(doc: ccl.Document) -> List(#(String, ccl.Value)) {
  case ccl.to_value(doc) {
    ccl.ObjectValue(pairs) -> pairs
    _ -> []
  }
}

fn run_build_model_test(
  name: String,
  input: String,
  expected: Expected,
  opts: ccl.Options,
) -> TestResult {
  case expected {
    ExpectedObject(count, expected_obj) -> {
      case ccl.parse_with(input, opts) {
        Ok(doc) -> {
          let m = ccl.to_model(doc)
          case compare_model(m, expected_obj) {
            True -> TestPassed(name, count)
            False ->
              mismatch(
                name,
                "Model mismatch",
                format_model(m),
                format_expected_object(expected_obj),
                count,
              )
          }
        }
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    }
    ExpectedCountOnly(count) -> {
      case ccl.parse_with(input, opts) {
        Ok(doc) -> {
          let _ = ccl.to_model(doc)
          TestPassed(name, count)
        }
        Error(e) ->
          error_fail(name, "Parse error: " <> describe_parse_error(e), count)
      }
    }
    _ -> error_fail(name, "Invalid expected type for build_model test", 0)
  }
}

fn compare_model(
  actual: ccl.Model,
  expected: Dict(String, ExpectedNode),
) -> Bool {
  let ccl.Model(pairs) = actual
  let actual_keys =
    list.map(pairs, fn(pair) { pair.0 }) |> list.sort(string.compare)
  let expected_keys = dict.keys(expected) |> list.sort(string.compare)
  case actual_keys == expected_keys {
    False -> False
    True ->
      list.all(pairs, fn(pair) {
        case dict.get(expected, pair.0) {
          Ok(NodeObject(inner)) -> compare_model(pair.1, inner)
          _ -> False
        }
      })
  }
}

fn format_model(m: ccl.Model) -> String {
  "\n" <> format_model_indent(m, 0)
}

fn format_model_indent(m: ccl.Model, indent: Int) -> String {
  let ccl.Model(pairs) = m
  let pad = string.repeat("  ", indent)
  let inner_pad = string.repeat("  ", indent + 1)
  case pairs {
    [] -> "{}"
    _ -> {
      let body =
        pairs
        |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
        |> list.map(fn(pair) {
          inner_pad
          <> string.inspect(pair.0)
          <> ": "
          <> format_model_indent(pair.1, indent + 1)
        })
        |> string.join(",\n")
      "{\n" <> body <> "\n" <> pad <> "}"
    }
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

/// Run a test that expects an error result, with options.
fn run_expected_error_test_with(
  name: String,
  input: String,
  path: List(String),
  count: Int,
  opts: ccl.Options,
  accessor: fn(ccl.Document, List(String)) -> Result(String, ccl.GetError),
) -> TestResult {
  case ccl.parse_with(input, opts) {
    Ok(doc) -> {
      case accessor(doc, path) {
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

/// Compare a CCL object's ordered entries against the expected object.
fn compare_objects(
  actual: List(#(String, ccl.Value)),
  expected: Dict(String, ExpectedNode),
) -> Bool {
  let actual_keys =
    list.map(actual, fn(pair) { pair.0 }) |> list.sort(string.compare)
  let expected_keys = dict.keys(expected) |> list.sort(string.compare)
  case actual_keys == expected_keys {
    False -> False
    True ->
      list.all(actual, fn(pair) {
        case dict.get(expected, pair.0) {
          Ok(node) -> compare_values(pair.1, node)
          Error(_) -> False
        }
      })
  }
}

/// Compare CCL value with expected node
fn compare_values(actual: ccl.Value, expected: ExpectedNode) -> Bool {
  case actual, expected {
    ccl.StringValue(s), NodeString(es) -> s == es
    ccl.ListValue(items), NodeList(el) -> {
      let str_items =
        items
        |> list.filter_map(fn(item) {
          case item {
            ccl.StringValue(s) -> Ok(s)
            _ -> Error(Nil)
          }
        })
      str_items == el
    }
    ccl.ObjectValue(pairs), NodeObject(eobj) -> compare_objects(pairs, eobj)
    _, _ -> False
  }
}

/// Format entries for error messages
fn format_entries(entries: List(ccl.Entry)) -> String {
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
  format_dict_indent(obj, indent, format_expected_node_indent)
}

fn format_expected_node_indent(node: ExpectedNode, indent: Int) -> String {
  case node {
    NodeString(s) -> string.inspect(s)
    NodeList(l) -> format_string_list(l)
    NodeObject(obj) -> format_expected_object_indent(obj, indent)
  }
}

/// Format a CCL object for error messages (pretty-printed)
fn format_ccl(pairs: List(#(String, ccl.Value))) -> String {
  "\n" <> format_ccl_indent(pairs, 0)
}

fn format_ccl_indent(pairs: List(#(String, ccl.Value)), indent: Int) -> String {
  let pad = string.repeat("  ", indent)
  let inner_pad = string.repeat("  ", indent + 1)
  case pairs {
    [] -> "{}"
    _ -> {
      let body =
        pairs
        |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
        |> list.map(fn(pair) {
          inner_pad
          <> string.inspect(pair.0)
          <> ": "
          <> format_ccl_value_indent(pair.1, indent + 1)
        })
        |> string.join(",\n")
      "{\n" <> body <> "\n" <> pad <> "}"
    }
  }
}

fn format_ccl_value_indent(value: ccl.Value, indent: Int) -> String {
  case value {
    ccl.StringValue(s) -> string.inspect(s)
    ccl.ListValue(items) ->
      items
      |> list.map(fn(item) {
        case item {
          ccl.StringValue(s) -> s
          _ -> "[complex]"
        }
      })
      |> format_string_list
    ccl.ObjectValue(pairs) -> format_ccl_indent(pairs, indent)
  }
}

/// Format a keyed dict for error messages, given a per-value formatter.
fn format_dict_indent(
  d: Dict(String, a),
  indent: Int,
  format_value: fn(a, Int) -> String,
) -> String {
  let pad = string.repeat("  ", indent)
  let inner_pad = string.repeat("  ", indent + 1)
  case dict.size(d) {
    0 -> "{}"
    _ -> {
      let entries =
        d
        |> dict.to_list
        |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
        |> list.map(fn(pair) {
          let #(k, v) = pair
          inner_pad <> string.inspect(k) <> ": " <> format_value(v, indent + 1)
        })
        |> string.join(",\n")
      "{\n" <> entries <> "\n" <> pad <> "}"
    }
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
