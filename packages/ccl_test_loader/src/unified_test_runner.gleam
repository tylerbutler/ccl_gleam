import ccl
import ccl_core
import ccl_types
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/io
import test_suite_types.{
  type TestCase, BuildHierarchyValidation, CombineValidation,
  CountedTypedValidation, CountedValidation, FilterValidation, GetIntValidation,
  GetStringValidation, GroupBySectionsValidation, ObjectValidation,
  ParseErrorValidation, ParseValidation, PrettyPrintValidation,
  RoundTripValidation,
}

pub type ValidationTestResult {
  ParseResult(
    actual: List(ccl_types.Entry),
    expected: List(ccl_types.Entry),
    count: Int,
    passed: Bool,
  )
  BuildHierarchyResult(
    actual: ccl_types.CCL,
    expected: ccl_types.CCL,
    count: Int,
    passed: Bool,
  )
  TypedAccessResult(
    function: String,
    test_cases: List(TypedTestCaseResult),
    total_count: Int,
    passed_count: Int,
  )
  FilterResult(
    actual: List(ccl_types.Entry),
    expected: List(ccl_types.Entry),
    count: Int,
    passed: Bool,
  )
  CombineResult(
    actual: List(ccl_types.Entry),
    expected: List(ccl_types.Entry),
    passed: Bool,
  )
  GroupBySectionsResult(
    actual: List(test_suite_types.SectionGroup),
    expected: List(test_suite_types.SectionGroup),
    count: Int,
    passed: Bool,
  )
  PrettyPrintResult(actual: String, expected: String, count: Int, passed: Bool)
  RoundTripResult(count: Int, passed: Bool, error: Option(String))
  ErrorResult(expected_error: Bool, actual_error: Option(String), count: Int, passed: Bool)
}

pub type TypedTestCaseResult {
  TypedTestCaseResult(
    args: List(String),
    expected: String,
    actual: Result(String, String),
    passed: Bool,
  )
}

pub fn run_test_case(test_case: TestCase) -> List(ValidationTestResult) {
  dict.fold(
    test_case.validations,
    [],
    fn(results, validation_key, validation_spec) {
      let result = case validation_spec {
        ParseValidation(CountedValidation(count, expected)) -> {
          case parse_ccl_input(test_case.input) {
            Ok(actual) -> {
              let passed = entries_equal(actual, expected)
              ParseResult(actual, expected, count, passed)
            }
            Error(_) -> ParseResult([], expected, count, False)
          }
        }

        BuildHierarchyValidation(ObjectValidation(count, expected)) -> {
          case parse_ccl_input(test_case.input) {
            Ok(entries) -> {
              case make_ccl_objects(entries) {
                Ok(actual) -> {
                  let passed = ccl_equal(actual, expected)
                  BuildHierarchyResult(actual, expected, count, passed)
                }
                Error(_) ->
                  BuildHierarchyResult(
                    ccl_types.CCL(dict.new()),
                    expected,
                    count,
                    False,
                  )
              }
            }
            Error(_) ->
              BuildHierarchyResult(
                ccl_types.CCL(dict.new()),
                expected,
                count,
                False,
              )
          }
        }

        GetStringValidation(CountedTypedValidation(count, cases)) -> {
          case run_full_pipeline(test_case.input) {
            Ok(ccl_obj) -> {
              let case_results =
                list.map(cases, fn(test_case_spec) {
                  case get_string_from_ccl(ccl_obj, test_case_spec.args) {
                    Ok(actual) -> {
                      let passed = actual == test_case_spec.expected
                      TypedTestCaseResult(
                        test_case_spec.args,
                        test_case_spec.expected,
                        Ok(actual),
                        passed,
                      )
                    }
                    Error(error) -> {
                      TypedTestCaseResult(
                        test_case_spec.args,
                        test_case_spec.expected,
                        Error(error),
                        False,
                      )
                    }
                  }
                })
              let passed_count = list.count(case_results, fn(r) { r.passed })
              TypedAccessResult("get_string", case_results, count, passed_count)
            }
            Error(_) -> {
              let failed_cases =
                list.map(cases, fn(spec) {
                  TypedTestCaseResult(
                    spec.args,
                    spec.expected,
                    Error("Parse failed"),
                    False,
                  )
                })
              TypedAccessResult("get_string", failed_cases, count, 0)
            }
          }
        }

        GetIntValidation(CountedTypedValidation(count, cases)) -> {
          case run_full_pipeline(test_case.input) {
            Ok(ccl_obj) -> {
              let case_results =
                list.map(cases, fn(test_case_spec) {
                  case get_int_from_ccl(ccl_obj, test_case_spec.args) {
                    Ok(actual) -> {
                      let passed =
                        string.inspect(actual) == test_case_spec.expected
                      TypedTestCaseResult(
                        test_case_spec.args,
                        test_case_spec.expected,
                        Ok(string.inspect(actual)),
                        passed,
                      )
                    }
                    Error(error) -> {
                      TypedTestCaseResult(
                        test_case_spec.args,
                        test_case_spec.expected,
                        Error(error),
                        False,
                      )
                    }
                  }
                })
              let passed_count = list.count(case_results, fn(r) { r.passed })
              TypedAccessResult("get_int", case_results, count, passed_count)
            }
            Error(_) -> {
              let failed_cases =
                list.map(cases, fn(spec) {
                  TypedTestCaseResult(
                    spec.args,
                    spec.expected,
                    Error("Parse failed"),
                    False,
                  )
                })
              TypedAccessResult("get_int", failed_cases, count, 0)
            }
          }
        }

        FilterValidation(CountedValidation(count, expected)) -> {
          case parse_ccl_input(test_case.input) {
            Ok(entries) -> {
              let actual = filter_ccl_entries(entries)
              let passed =
                entries_equal(actual, expected) && list.length(actual) == count
              FilterResult(actual, expected, count, passed)
            }
            Error(_) -> FilterResult([], expected, count, False)
          }
        }

        CombineValidation(combine_spec) -> {
          // Use the ComposeSpec left/right entries instead of parsing test inputs
          let combined = combine_entries(combine_spec.left, combine_spec.right)
          let passed = entries_equal(combined, combine_spec.expected)
          CombineResult(combined, combine_spec.expected, passed)
        }

        GroupBySectionsValidation(section_spec) -> {
          case parse_ccl_input(test_case.input) {
            Ok(entries) -> {
              // Use ccl.group_by_sections to group the entries
              let actual_sections = group_by_sections_entries(entries)
              let passed =
                sections_equal(actual_sections, section_spec.expected_sections)
                && list.length(actual_sections) == section_spec.count
              GroupBySectionsResult(
                actual_sections,
                section_spec.expected_sections,
                section_spec.count,
                passed,
              )
            }
            Error(_) ->
              GroupBySectionsResult(
                [],
                section_spec.expected_sections,
                section_spec.count,
                False,
              )
          }
        }

        PrettyPrintValidation(pretty_spec) -> {
          case parse_ccl_input(test_case.input) {
            Ok(entries) -> {
              let actual = pretty_print_entries(entries)
              let passed = actual == pretty_spec.expected
              PrettyPrintResult(actual, pretty_spec.expected, pretty_spec.count, passed)
            }
            Error(_) -> PrettyPrintResult("", pretty_spec.expected, pretty_spec.count, False)
          }
        }

        RoundTripValidation(round_trip_spec) -> {
          // Implement round-trip validation: parse → pretty-print → parse
          case round_trip_spec.property {
            "identity" -> {
              case parse_ccl_input(test_case.input) {
                Ok(entries_1) -> {
                  // Pretty print the parsed entries
                  let pretty_printed = pretty_print_entries(entries_1)

                  // Parse the pretty-printed result
                  case parse_ccl_input(pretty_printed) {
                    Ok(entries_2) -> {
                      // Check if both parsed results are equivalent
                      let passed = entries_1 == entries_2
                      case passed {
                        True -> RoundTripResult(round_trip_spec.count, True, None)
                        False ->
                          RoundTripResult(
                            round_trip_spec.count,
                            False,
                            Some("Round-trip failed: parsed results differ"),
                          )
                      }
                    }
                    Error(err) ->
                      RoundTripResult(
                        round_trip_spec.count,
                        False,
                        Some("Failed to parse pretty-printed result: " <> err),
                      )
                  }
                }
                Error(err) ->
                  RoundTripResult(round_trip_spec.count, False, Some("Failed to parse input: " <> err))
              }
            }
            _ ->
              RoundTripResult(
                round_trip_spec.count,
                False,
                Some(
                  "Unsupported round-trip property: "
                  <> round_trip_spec.property,
                ),
              )
          }
        }

        ParseErrorValidation(error_spec) -> {
          // Test that parsing produces an error when expected
          case parse_ccl_input(test_case.input) {
            Ok(_) -> {
              // Parse succeeded but error was expected
              case error_spec.error {
                True -> ErrorResult(True, None, error_spec.count, False)
                // Expected error but got success
                False -> ErrorResult(False, None, error_spec.count, True)
                // Expected success and got success
              }
            }
            Error(parse_error) -> {
              // Parse failed - check if error was expected
              case error_spec.error {
                True -> {
                  // Error was expected - check error type/message if specified
                  case error_spec.error_type, error_spec.error_message {
                    Some(expected_type), Some(expected_msg) -> {
                      // Both type and message specified - check both
                      let error_str = string.inspect(parse_error)
                      let type_match = string.contains(error_str, expected_type)
                      let msg_match = string.contains(error_str, expected_msg)
                      ErrorResult(
                        True,
                        Some(error_str),
                        error_spec.count,
                        type_match && msg_match,
                      )
                    }
                    Some(expected_type), None -> {
                      // Only type specified - check type
                      let error_str = string.inspect(parse_error)
                      let type_match = string.contains(error_str, expected_type)
                      ErrorResult(True, Some(error_str), error_spec.count, type_match)
                    }
                    None, Some(expected_msg) -> {
                      // Only message specified - check message
                      let error_str = string.inspect(parse_error)
                      let msg_match = string.contains(error_str, expected_msg)
                      ErrorResult(True, Some(error_str), error_spec.count, msg_match)
                    }
                    None, None -> {
                      // Just expecting any error
                      ErrorResult(True, Some(string.inspect(parse_error)), error_spec.count, True)
                    }
                  }
                }
                False ->
                  ErrorResult(False, Some(string.inspect(parse_error)), error_spec.count, False)
                // Error occurred but not expected
              }
            }
          }
        }

        // Handle unknown validation types
        _ ->
          ErrorResult(
            False,
            Some("Unimplemented validation: " <> validation_key),
            1,  // Default count for unimplemented validations
            False,
          )
      }

      [result, ..results]
    },
  )
}

// Helper functions that interface with the actual CCL implementation
fn parse_ccl_input(input: String) -> Result(List(ccl_types.Entry), String) {
  // Call the actual CCL core parser
  case ccl_core.parse(input) {
    Ok(entries) -> Ok(entries)
    Error(err) -> Error(string.inspect(err))
  }
}

// Helper function to combine entries (right overrides left on duplicate keys)
fn combine_entries(
  left: List(ccl_types.Entry),
  right: List(ccl_types.Entry),
) -> List(ccl_types.Entry) {
  // Create a dict from left entries
  let left_dict =
    left
    |> list.map(fn(entry) { #(entry.key, entry.value) })
    |> dict.from_list()

  // Add right entries, overriding any duplicates
  let right_dict =
    right
    |> list.map(fn(entry) { #(entry.key, entry.value) })
    |> dict.from_list()

  // Merge dicts (right overrides left)
  let merged_dict = dict.merge(left_dict, right_dict)

  // Convert back to Entry list, maintaining order (left first, then new right entries)
  let left_keys = left |> list.map(fn(entry) { entry.key })
  let right_keys = right |> list.map(fn(entry) { entry.key })
  let all_keys = list.append(left_keys, right_keys) |> list.unique()

  all_keys
  |> list.filter_map(fn(key) {
    case dict.get(merged_dict, key) {
      Ok(value) -> Ok(ccl_types.Entry(key, value))
      Error(_) -> Error(Nil)
    }
  })
}

fn make_ccl_objects(
  entries: List(ccl_types.Entry),
) -> Result(ccl_types.CCL, String) {
  // Call the actual CCL core object constructor
  Ok(ccl_core.build_hierarchy(entries))
}

fn run_full_pipeline(input: String) -> Result(ccl_types.CCL, String) {
  use entries <- result.try(parse_ccl_input(input))
  make_ccl_objects(entries)
}

fn get_string_from_ccl(
  ccl_obj: ccl_types.CCL,
  path: List(String),
) -> Result(String, String) {
  // Call the actual CCL typed access function
  case path {
    [key] ->
      ccl.get_smart_value(ccl_obj, key) |> result.map_error(string.inspect)
    [key, ..rest] -> {
      case ccl.get(ccl_obj, key) {
        Ok(ccl.CclObject(nested_ccl)) -> get_string_from_ccl(nested_ccl, rest)
        Ok(_) ->
          Error(
            "Path " <> string.join(path, ".") <> " does not lead to an object",
          )
        Error(err) -> Error(string.inspect(err))
      }
    }
    [] -> Error("Empty path provided")
  }
}

fn get_int_from_ccl(
  ccl_obj: ccl_types.CCL,
  path: List(String),
) -> Result(Int, String) {
  // Call the actual CCL typed access function
  case path {
    [key] -> ccl.get_int(ccl_obj, key) |> result.map_error(string.inspect)
    [key, ..rest] -> {
      case ccl.get(ccl_obj, key) {
        Ok(ccl.CclObject(nested_ccl)) -> get_int_from_ccl(nested_ccl, rest)
        Ok(_) ->
          Error(
            "Path " <> string.join(path, ".") <> " does not lead to an object",
          )
        Error(err) -> Error(string.inspect(err))
      }
    }
    [] -> Error("Empty path provided")
  }
}

fn filter_ccl_entries(entries: List(ccl_types.Entry)) -> List(ccl_types.Entry) {
  // Call the actual CCL filter function to remove comment entries
  ccl.filter(entries, ["/", "#", "//"])
}

fn pretty_print_entries(entries: List(ccl_types.Entry)) -> String {
  // Call the actual CCL pretty printer
  ccl.pretty_print_entries(entries)
}

fn group_by_sections_entries(
  entries: List(ccl_types.Entry),
) -> List(test_suite_types.SectionGroup) {
  // Call the actual CCL section grouping function and convert to our type
  let ccl_sections = ccl.group_by_sections(entries)
  list.map(ccl_sections, fn(ccl_section) {
    // Convert from ccl.SectionGroup to test_suite_types.SectionGroup
    test_suite_types.SectionGroup(
      header: ccl_section.header,
      entries: ccl_section.entries,
    )
  })
}

fn sections_equal(
  a: List(test_suite_types.SectionGroup),
  b: List(test_suite_types.SectionGroup),
) -> Bool {
  case list.length(a) == list.length(b) {
    False -> False
    True -> {
      list.all(list.zip(a, b), fn(pair) {
        case pair {
          #(section_a, section_b) -> {
            section_a.header == section_b.header
            && entries_equal(section_a.entries, section_b.entries)
          }
        }
      })
    }
  }
}

fn entries_equal(a: List(ccl_types.Entry), b: List(ccl_types.Entry)) -> Bool {
  // Deep comparison of entry lists
  list.length(a) == list.length(b)
  && list.all(list.zip(a, b), fn(pair) {
    case pair {
      #(ccl_types.Entry(key1, value1), ccl_types.Entry(key2, value2)) -> {
        key1 == key2 && value1 == value2
      }
    }
  })
}

fn ccl_equal(a: ccl_types.CCL, b: ccl_types.CCL) -> Bool {
  // Deep comparison of CCL objects
  case a, b {
    ccl_types.CCL(dict_a), ccl_types.CCL(dict_b) -> {
      // First check if sizes match
      case dict.size(dict_a) == dict.size(dict_b) {
        False -> False
        True -> {
          // Check that all keys exist in both and values are equal
          dict.fold(dict_a, True, fn(acc, key, value_a) {
            case acc {
              False -> False
              // Short circuit if already failed
              True -> {
                case dict.get(dict_b, key) {
                  Ok(value_b) -> ccl_equal(value_a, value_b)
                  Error(_) -> False
                  // Key missing in dict_b
                }
              }
            }
          })
        }
      }
    }
  }
}

pub fn is_validation_result_passed(result: ValidationTestResult) -> Bool {
  case result {
    ParseResult(_, _, _, passed) -> passed
    BuildHierarchyResult(_, _, _, passed) -> passed
    TypedAccessResult(_, _, total_count, passed_count) ->
      passed_count == total_count
    FilterResult(_, _, _, passed) -> passed
    CombineResult(_, _, passed) -> passed
    GroupBySectionsResult(_, _, _, passed) -> passed
    PrettyPrintResult(_, _, _, passed) -> passed
    RoundTripResult(_, passed, _) -> passed
    ErrorResult(_, _, _, passed) -> passed
  }
}

pub fn get_validation_result_name(result: ValidationTestResult) -> String {
  case result {
    ParseResult(_, _, _, _) -> "parse"
    BuildHierarchyResult(_, _, _, _) -> "build_hierarchy"
    TypedAccessResult(function, _, _, _) -> function
    FilterResult(_, _, _, _) -> "filter"
    CombineResult(_, _, _) -> "combine"
    GroupBySectionsResult(_, _, _, _) -> "group_by_sections"
    PrettyPrintResult(_, _, _, _) -> "pretty_print"
    RoundTripResult(_, _, _) -> "round_trip"
    ErrorResult(_, _, _, _) -> "error"
  }
}

pub fn get_assertion_count(result: ValidationTestResult) -> Int {
  case result {
    ParseResult(_, _, count, _) -> count
    BuildHierarchyResult(_, _, count, _) -> count
    TypedAccessResult(_, _, total_count, _) -> total_count
    FilterResult(_, _, count, _) -> count
    CombineResult(_, _, _) -> 1  // Combined tests always count as 1 assertion
    GroupBySectionsResult(_, _, count, _) -> count
    PrettyPrintResult(_, _, count, _) -> count
    RoundTripResult(count, _, _) -> count
    ErrorResult(_, _, count, _) -> count
  }
}

pub fn get_test_case_assertion_count(test_case: TestCase) -> Int {
  let validation_results = run_test_case(test_case)
  list.fold(validation_results, 0, fn(total, result) {
    total + get_assertion_count(result)
  })
}

pub fn get_test_case_passed_assertion_count(test_case: TestCase) -> Int {
  let validation_results = run_test_case(test_case)
  list.fold(validation_results, 0, fn(total, result) {
    case is_validation_result_passed(result) {
      True -> total + get_assertion_count(result)
      False -> total
    }
  })
}

/// Test suite execution results with assertion counting
pub type TestSuiteResult {
  TestSuiteResult(
    suite_name: String,
    expected_assertions: Int,
    actual_assertions: Int,
    passed_assertions: Int,
    test_count: Int,
    passed_test_count: Int,
  )
}

/// Run a test suite and return results with assertion counts
pub fn run_test_suite_with_counts(
  test_suite: test_suite_types.TestSuite,
) -> TestSuiteResult {
  let validation_results =
    list.map(test_suite.tests, fn(test_case) { run_test_case(test_case) })
    |> list.flatten()

  let actual_assertions = list.fold(validation_results, 0, fn(total, result) {
    total + get_assertion_count(result)
  })
  
  let passed_assertions = list.fold(validation_results, 0, fn(total, result) {
    case is_validation_result_passed(result) {
      True -> total + get_assertion_count(result)
      False -> total
    }
  })

  let passed_test_count = list.count(test_suite.tests, fn(test_case) {
    let test_results = run_test_case(test_case)
    list.all(test_results, is_validation_result_passed)
  })

  let expected_assertions = case test_suite.llm_metadata {
    option.Some(metadata) -> metadata.assertion_count
    option.None -> actual_assertions  // Fallback if no metadata
  }

  TestSuiteResult(
    suite_name: test_suite.suite,
    expected_assertions: expected_assertions,
    actual_assertions: actual_assertions,
    passed_assertions: passed_assertions,
    test_count: list.length(test_suite.tests),
    passed_test_count: passed_test_count,
  )
}

/// Display test suite results with assertion counting
pub fn display_test_suite_results(result: TestSuiteResult) -> Nil {
  io.println("=== " <> result.suite_name <> " ===")
  
  // Test counts
  io.println("Tests: " <> string.inspect(result.passed_test_count) <> "/" 
    <> string.inspect(result.test_count) <> " passed")
  
  // Assertion counts
  io.println("Assertions: " <> string.inspect(result.passed_assertions) <> "/"
    <> string.inspect(result.actual_assertions) <> " passed")
    
  // Expected vs actual assertion count comparison
  case result.expected_assertions == result.actual_assertions {
    True -> {
      io.println("✅ Assertion count matches expected: " <> string.inspect(result.expected_assertions))
    }
    False -> {
      io.println("⚠️  Assertion count mismatch!")
      io.println("   Expected: " <> string.inspect(result.expected_assertions))
      io.println("   Actual: " <> string.inspect(result.actual_assertions))
      io.println("   Difference: " <> string.inspect(result.actual_assertions - result.expected_assertions))
    }
  }
  
  // Success rate
  case result.actual_assertions {
    0 -> io.println("Success rate: 0% (no assertions)")
    _ -> {
      let success_rate = result.passed_assertions * 100 / result.actual_assertions
      io.println("Success rate: " <> string.inspect(success_rate) <> "%")
    }
  }
  
  io.println("")
}

/// Run a single test suite file and display assertion counts
pub fn run_and_display_test_suite_file(file_path: String) -> Nil {
  case test_suite_types.load_test_suite(file_path) {
    Ok(test_suite) -> {
      let result = run_test_suite_with_counts(test_suite)
      display_test_suite_results(result)
    }
    Error(err) -> {
      io.println("Failed to load test suite from " <> file_path <> ": " <> err)
    }
  }
}

/// Run multiple test suite files and display assertion counts
pub fn run_and_display_multiple_test_suites(file_paths: List(String)) -> Nil {
  io.println("=== CCL Test Runner with Assertion Counting ===")
  io.println("")
  
  let results = list.filter_map(file_paths, fn(file_path) {
    case test_suite_types.load_test_suite(file_path) {
      Ok(test_suite) -> {
        let result = run_test_suite_with_counts(test_suite)
        display_test_suite_results(result)
        Ok(result)
      }
      Error(err) -> {
        io.println("Failed to load test suite from " <> file_path <> ": " <> err)
        io.println("")
        Error(err)
      }
    }
  })
  
  // Display summary
  case list.length(results) {
    0 -> {
      io.println("=== SUMMARY ===")
      io.println("No test suites were successfully loaded.")
    }
    _ -> {
      let total_tests = list.fold(results, 0, fn(acc, result) { acc + result.test_count })
      let total_passed_tests = list.fold(results, 0, fn(acc, result) { acc + result.passed_test_count })
      let total_assertions = list.fold(results, 0, fn(acc, result) { acc + result.actual_assertions })
      let total_passed_assertions = list.fold(results, 0, fn(acc, result) { acc + result.passed_assertions })
      let total_expected_assertions = list.fold(results, 0, fn(acc, result) { acc + result.expected_assertions })
      
      io.println("=== OVERALL SUMMARY ===")
      io.println("Test suites run: " <> string.inspect(list.length(results)))
      io.println("Total tests: " <> string.inspect(total_passed_tests) <> "/" <> string.inspect(total_tests) <> " passed")
      io.println("Total assertions: " <> string.inspect(total_passed_assertions) <> "/" <> string.inspect(total_assertions) <> " passed")
      io.println("Expected total assertions: " <> string.inspect(total_expected_assertions))
      
      case total_expected_assertions == total_assertions {
        True -> io.println("✅ Overall assertion count matches expected")
        False -> io.println("⚠️  Overall assertion count mismatch: difference " <> string.inspect(total_assertions - total_expected_assertions))
      }
    }
  }
}
