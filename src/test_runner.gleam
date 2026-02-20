/// Test runner that executes tests against a CCL implementation
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
  type TestResult, type TestSuite, type TestSuiteResult, ExpectedBool,
  ExpectedCountOnly, ExpectedEntries, ExpectedError, ExpectedFloat,
  ExpectedInt, ExpectedList, ExpectedObject, ExpectedValue, NodeList,
  NodeObject, NodeString, TestFailed, TestPassed, TestSkipped, TestSuiteResult,
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

/// Run all tests from a directory against an implementation
pub fn run_test_directory(
  dir: String,
  config: ImplementationConfig,
  impl: CclImplementation,
) -> Result(List(TestSuiteResult), String) {
  use files <- result.try(test_loader.list_test_files(dir))

  birch.debug_m("Found test files", [
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
  birch.debug_m("Loading test file", [#("path", path)])

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
    "parse_indented" ->
      run_parse_indented_test(tc.name, input, tc.expected, impl)
    "print" -> run_print_test(tc.name, input, tc.expected, impl)
    "canonical_format" ->
      run_canonical_format_test(tc.name, input, tc.expected, impl)
    "round_trip" -> run_round_trip_test(tc.name, input, tc.expected, impl)
    "filter" -> run_filter_test(tc.name, input, tc.expected, impl)
    "compose_associative" ->
      run_compose_associative_test(tc.name, tc.inputs, tc.expected, impl)
    "identity_left" ->
      run_identity_left_test(tc.name, tc.inputs, tc.expected, impl)
    "identity_right" ->
      run_identity_right_test(tc.name, tc.inputs, tc.expected, impl)
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
                "Entries mismatch:\n"
                  <> diff.entries_diff(
                  expected_tuples,
                  actual_tuples,
                  default_theme,
                ),
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
                "Print mismatch:\n"
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

/// Run a parse_indented test - like parse but uses the parse_indented function
fn run_parse_indented_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedEntries(count, expected_entries) -> {
      case impl.parse_indented(input) {
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
                "Entries mismatch:\n"
                  <> diff.entries_diff(
                  expected_tuples,
                  actual_tuples,
                  default_theme,
                ),
                count,
              )
            }
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedError(count, True) -> {
      case impl.parse_indented(input) {
        Ok(_) -> TestFailed(name, "Expected error but got success", count)
        Error(_) -> TestPassed(name, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for parse_indented test", 0)
  }
}

/// Run a canonical_format test - parse then print, compare output with expected
fn run_canonical_format_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedValue(count, expected_value) -> {
      case impl.parse(input) {
        Ok(entries) -> {
          let formatted = impl.print(entries)
          case formatted == expected_value {
            True -> TestPassed(name, count)
            False -> {
              let default_theme = theme.default()
              TestFailed(
                name,
                "Canonical format mismatch:\n"
                  <> diff.value_diff(
                  expected_value,
                  formatted,
                  default_theme,
                ),
                count,
              )
            }
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    _ ->
      TestFailed(name, "Invalid expected type for canonical_format test", 0)
  }
}

/// Run a round_trip test - parse(print(parse(x))) == parse(x)
fn run_round_trip_test(
  name: String,
  input: String,
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedBool(count, True) -> {
      case impl.parse(input) {
        Ok(parsed) -> {
          let printed = impl.print(parsed)
          case impl.parse(printed) {
            Ok(reparsed) -> {
              case parsed == reparsed {
                True -> TestPassed(name, count)
                False -> {
                  let default_theme = theme.default()
                  let original_tuples =
                    parsed |> list.map(fn(e) { #(e.key, e.value) })
                  let reparsed_tuples =
                    reparsed |> list.map(fn(e) { #(e.key, e.value) })
                  TestFailed(
                    name,
                    "Round-trip mismatch: parse(print(parse(x))) != parse(x)\n"
                      <> diff.entries_diff(
                      original_tuples,
                      reparsed_tuples,
                      default_theme,
                    ),
                    count,
                  )
                }
              }
            }
            Error(e) ->
              TestFailed(name, "Re-parse error: " <> e, count)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedValue(count, _expected_value) -> {
      // Some round_trip tests expect a specific printed value
      case impl.parse(input) {
        Ok(parsed) -> {
          let printed = impl.print(parsed)
          case impl.parse(printed) {
            Ok(reparsed) -> {
              case parsed == reparsed {
                True -> TestPassed(name, count)
                False -> {
                  let default_theme = theme.default()
                  let original_tuples =
                    parsed |> list.map(fn(e) { #(e.key, e.value) })
                  let reparsed_tuples =
                    reparsed |> list.map(fn(e) { #(e.key, e.value) })
                  TestFailed(
                    name,
                    "Round-trip mismatch: parse(print(parse(x))) != parse(x)\n"
                      <> diff.entries_diff(
                      original_tuples,
                      reparsed_tuples,
                      default_theme,
                    ),
                    count,
                  )
                }
              }
            }
            Error(e) ->
              TestFailed(name, "Re-parse error: " <> e, count)
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    _ -> TestFailed(name, "Invalid expected type for round_trip test", 0)
  }
}

/// Run a filter test - parse then filter (remove comments), compare entries
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
          let expected_list =
            expected_entries
            |> list.map(fn(e) { Entry(e.key, e.value) })
          case filtered == expected_list {
            True -> TestPassed(name, count)
            False -> {
              let expected_tuples =
                expected_list |> list.map(fn(e) { #(e.key, e.value) })
              let actual_tuples =
                filtered |> list.map(fn(e) { #(e.key, e.value) })
              let default_theme = theme.default()
              TestFailed(
                name,
                "Filter mismatch:\n"
                  <> diff.entries_diff(
                  expected_tuples,
                  actual_tuples,
                  default_theme,
                ),
                count,
              )
            }
          }
        }
        Error(e) -> TestFailed(name, "Parse error: " <> e, count)
      }
    }
    ExpectedCountOnly(count) -> {
      // Just verify filter doesn't crash
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

/// Run a compose_associative test - verify (a·b)·c == a·(b·c)
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
              // (a·b)·c
              let ab = impl.compose(a, b)
              let left = impl.compose(ab, c)
              // a·(b·c)
              let bc = impl.compose(b, c)
              let right = impl.compose(a, bc)
              case left == right {
                True -> TestPassed(name, count)
                False -> {
                  let default_theme = theme.default()
                  let left_tuples =
                    left |> list.map(fn(e) { #(e.key, e.value) })
                  let right_tuples =
                    right |> list.map(fn(e) { #(e.key, e.value) })
                  TestFailed(
                    name,
                    "Compose not associative: (a·b)·c != a·(b·c)\n"
                      <> diff.entries_diff(
                      left_tuples,
                      right_tuples,
                      default_theme,
                    ),
                    count,
                  )
                }
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
      TestFailed(
        name,
        "Invalid expected type for compose_associative test",
        0,
      )
  }
}

/// Run an identity_left test - verify compose(empty, x) == x
fn run_identity_left_test(
  name: String,
  inputs: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedBool(count, True) -> {
      case inputs {
        [input_empty, input_x] -> {
          case impl.parse(input_empty), impl.parse(input_x) {
            Ok(empty), Ok(x) -> {
              let result = impl.compose(empty, x)
              case result == x {
                True -> TestPassed(name, count)
                False -> {
                  let default_theme = theme.default()
                  let expected_tuples =
                    x |> list.map(fn(e) { #(e.key, e.value) })
                  let actual_tuples =
                    result |> list.map(fn(e) { #(e.key, e.value) })
                  TestFailed(
                    name,
                    "Identity left failed: compose(empty, x) != x\n"
                      <> diff.entries_diff(
                      expected_tuples,
                      actual_tuples,
                      default_theme,
                    ),
                    count,
                  )
                }
              }
            }
            _, _ -> TestFailed(name, "Parse error on one or more inputs", count)
          }
        }
        _ ->
          TestFailed(
            name,
            "identity_left requires exactly 2 inputs, got "
              <> int.to_string(list.length(inputs)),
            0,
          )
      }
    }
    _ ->
      TestFailed(name, "Invalid expected type for identity_left test", 0)
  }
}

/// Run an identity_right test - verify compose(x, empty) == x
fn run_identity_right_test(
  name: String,
  inputs: List(String),
  expected: Expected,
  impl: CclImplementation,
) -> TestResult {
  case expected {
    ExpectedBool(count, True) -> {
      case inputs {
        [input_x, input_empty] -> {
          case impl.parse(input_x), impl.parse(input_empty) {
            Ok(x), Ok(empty) -> {
              let result = impl.compose(x, empty)
              case result == x {
                True -> TestPassed(name, count)
                False -> {
                  let default_theme = theme.default()
                  let expected_tuples =
                    x |> list.map(fn(e) { #(e.key, e.value) })
                  let actual_tuples =
                    result |> list.map(fn(e) { #(e.key, e.value) })
                  TestFailed(
                    name,
                    "Identity right failed: compose(x, empty) != x\n"
                      <> diff.entries_diff(
                      expected_tuples,
                      actual_tuples,
                      default_theme,
                    ),
                    count,
                  )
                }
              }
            }
            _, _ -> TestFailed(name, "Parse error on one or more inputs", count)
          }
        }
        _ ->
          TestFailed(
            name,
            "identity_right requires exactly 2 inputs, got "
              <> int.to_string(list.length(inputs)),
            0,
          )
      }
    }
    _ ->
      TestFailed(name, "Invalid expected type for identity_right test", 0)
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
            False -> {
              let default_theme = theme.default()
              let expected_lines =
                render_object.to_ansi(expected_obj, default_theme)
                |> string.split("\n")
              let actual_lines =
                format_ccl(obj) |> string.split("\n")
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
                    "Value mismatch:\n"
                      <> diff.inline_diff(
                      render_value.to_ansi(expected_value, default_theme),
                      render_value.to_ansi(value, default_theme),
                    ),
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
                False -> {
                  let default_theme = theme.default()
                  TestFailed(
                    name,
                    "Value mismatch:\n"
                      <> diff.inline_diff(
                      typed.int_to_ansi(expected_value, default_theme),
                      typed.int_to_ansi(value, default_theme),
                    ),
                    count,
                  )
                }
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
                False -> {
                  let default_theme = theme.default()
                  TestFailed(
                    name,
                    "Value mismatch:\n"
                      <> diff.inline_diff(
                      typed.bool_to_ansi(expected_value, default_theme),
                      typed.bool_to_ansi(value, default_theme),
                    ),
                    count,
                  )
                }
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
                False -> {
                  let default_theme = theme.default()
                  TestFailed(
                    name,
                    "Value mismatch:\n"
                      <> diff.inline_diff(
                      typed.float_to_ansi(expected_value, default_theme),
                      typed.float_to_ansi(value, default_theme),
                    ),
                    count,
                  )
                }
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
                False -> {
                  let default_theme = theme.default()
                  let expected_lines =
                    render_list.to_ansi(expected_list, default_theme)
                    |> string.split("\n")
                  let actual_lines =
                    render_list.to_ansi(value, default_theme)
                    |> string.split("\n")
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

/// Print test results report
pub fn print_results(
  results: List(TestSuiteResult),
  config: test_types.ImplementationConfig,
  test_dir: String,
  grouping: test_types.FailureGrouping,
) -> Nil {
  report.print_report_grouped(results, config, test_dir, grouping)
}
