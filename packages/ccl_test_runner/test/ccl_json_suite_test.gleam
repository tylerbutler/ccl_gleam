/// Startest-based wrapper for the CCL JSON test suite.
///
/// Loads all JSON test files from ccl-test-data/, converts each test case
/// into a startest `it`/`xit` node, and runs them through `gleam test`.
///
/// Tests are grouped by **validation type** (parse, build_hierarchy,
/// get_string, etc.) so that related assertions cluster together regardless
/// of which JSON file they originate from.
///
/// Structure: `CCL JSON Suite ❯ <validation> ❯ <test name>`
///
/// On failure the source filename is included in the error message so you
/// can locate the test definition quickly.
///
/// Configuration is loaded from ccl-config.yaml at the project root. If the
/// file is missing, falls back to the built-in full_config().
///
/// The CLI test runner (`gleam run -- run`) is still available for the TUI,
/// stats, and other specialized use cases.
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import startest
import startest/assertion_error.{AssertionError}
import test_runner/config
import test_runner/filter
import test_runner/loader
import test_runner/runner
import test_runner/types.{type TestCase, TestFailed, TestPassed, TestSkipped}

const test_data_dir = "./ccl-test-data"

/// A test case paired with the filename it was loaded from.
type TaggedTest {
  TaggedTest(file: String, test_case: TestCase)
}

pub fn main() {
  startest.run(startest.default_config())
}

/// Generates a startest `describe` tree grouped by validation type.
///
/// Structure: `CCL JSON Suite ❯ <validation> ❯ <test name>`
///
/// Tests that are incompatible with the current implementation config
/// are marked as skipped via `xit`.
pub fn ccl_json_suite_tests() {
  let config = case config.load_config("../../ccl-config.yaml") {
    Ok(cfg) -> cfg
    Error(_) -> filter.full_config()
  }

  let files = case loader.list_test_files(test_data_dir) {
    Ok(f) -> f
    Error(e) -> {
      panic as { "Failed to list test files in " <> test_data_dir <> ": " <> e }
    }
  }

  // Load all test cases, tagging each with its source filename
  let all_tests =
    files
    |> list.flat_map(fn(file) {
      let filename = file_basename(file)
      case loader.load_test_file(file) {
        Ok(suite) ->
          suite.tests
          |> list.map(fn(tc) { TaggedTest(file: filename, test_case: tc) })
        Error(e) -> {
          panic as { "Failed to load " <> file <> ": " <> e }
        }
      }
    })

  // Group tests by validation type
  let by_validation =
    group_by(all_tests, fn(tagged) { tagged.test_case.validation })

  // Sort validation groups alphabetically for stable output
  let sorted_groups =
    by_validation
    |> dict.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })

  startest.describe(
    "CCL JSON Suite",
    sorted_groups
      |> list.map(fn(group) {
        let #(validation, tagged_tests) = group
        startest.describe(
          validation,
          tagged_tests
            |> list.map(fn(tagged) {
              let tc = tagged.test_case
              case filter.get_skip_reason(config, tc) {
                // Incompatible — skip it with reason in test name
                Error(reason) ->
                  startest.xit(tc.name <> "\n    " <> reason, fn() { Nil })
                // Compatible — run through the existing runner
                Ok(Nil) ->
                  startest.it(tc.name, fn() {
                    let result = runner.run_single_test(tc, config)
                    assert_test_result(result, tagged.file)
                  })
              }
            }),
        )
      }),
  )
}

/// Convert a TestResult from the existing runner into a startest assertion.
///
/// Passed tests succeed silently. Failed tests raise an `AssertionError` with
/// separate actual/expected fields so startest renders its coloured diff output.
/// The source filename is prepended to the reason so failures show provenance.
/// Skipped results should not reach here (handled by `xit` above), but are
/// tolerated as a pass.
fn assert_test_result(result: types.TestResult, file: String) -> Nil {
  case result {
    TestPassed(_, _) -> Nil
    TestFailed(_name, detail) -> {
      let reason = "[" <> file <> "] " <> detail.reason
      AssertionError(reason, detail.actual, detail.expected)
      |> assertion_error.raise
    }
    TestSkipped(_, _) -> Nil
  }
}

/// Group a list of items by a key function, preserving insertion order.
fn group_by(
  items: List(a),
  key_fn: fn(a) -> String,
) -> dict.Dict(String, List(a)) {
  list.fold(items, dict.new(), fn(acc, item) {
    let key = key_fn(item)
    let existing = case dict.get(acc, key) {
      Ok(vals) -> vals
      Error(_) -> []
    }
    dict.insert(acc, key, list.append(existing, [item]))
  })
}

/// Extract the filename from a path.
fn file_basename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}
