/// Test report rendering for CLI output.
///
/// Two-phase layout: compact overview, then detailed failures.
/// Failures can be grouped by file (default) or by validation kind.
import birch/handler/console
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import render/ansi
import shore/style
import test_types.{
  type FailureGrouping, type ImplementationConfig, type TestCaseResult,
  type TestResult, type TestSuiteResult, GroupByFile, GroupByValidation,
  TestFailed, TestPassed, TestSkipped,
}
import util

/// Maximum number of failures to show per group in the detail section.
const max_failures_per_group = 5

// ============================================================================
// Public API
// ============================================================================

/// Print the full test report with default grouping (by file).
pub fn print_report(
  results: List(TestSuiteResult),
  config: ImplementationConfig,
  test_dir: String,
) -> Nil {
  print_report_grouped(results, config, test_dir, GroupByFile)
}

/// Print the full test report with the specified failure grouping.
pub fn print_report_grouped(
  results: List(TestSuiteResult),
  config: ImplementationConfig,
  test_dir: String,
  grouping: FailureGrouping,
) -> Nil {
  // Header box
  let functions_line = "Functions: " <> string.join(config.functions, ", ")
  let dir_line = "Directory: " <> test_dir
  console.write_box_with_title(
    functions_line <> "\n" <> dir_line,
    "CCL Test Runner",
  )
  io.println("")

  // Phase 1: compact overview (always by file)
  print_results_overview(results)

  // Phase 2: failure details (grouped as requested)
  let has_failures = list.any(results, fn(r) { r.failed > 0 })
  case has_failures {
    False -> Nil
    True ->
      case grouping {
        GroupByFile -> print_failures_by_file(results)
        GroupByValidation -> print_failures_by_validation(results)
      }
  }

  // Phase 3: feature breakdown
  print_feature_breakdown(results)

  // Phase 4: summary box
  print_summary(results)
}

// ============================================================================
// Phase 1: Compact overview
// ============================================================================

fn print_results_overview(results: List(TestSuiteResult)) -> Nil {
  console.with_group("Results", fn() { list.each(results, print_file_line) })
  io.println("")
}

fn print_file_line(r: TestSuiteResult) -> Nil {
  let name = util.get_filename(r.file)
  let counts = format_counts_inline(r)

  let icon = case r.failed > 0 {
    True -> ansi.fg("✖", style.Red)
    False -> ansi.fg("✔", style.Green)
  }

  io.println("  " <> icon <> " " <> name <> "  " <> counts)
}

fn format_counts_inline(r: TestSuiteResult) -> String {
  let parts = []

  let parts = case r.passed > 0 {
    True ->
      list.append(parts, [
        ansi.fg(int.to_string(r.passed) <> " passed", style.Green),
      ])
    False -> parts
  }

  let parts = case r.failed > 0 {
    True ->
      list.append(parts, [
        ansi.fg(int.to_string(r.failed) <> " failed", style.Red),
      ])
    False -> parts
  }

  let parts = case r.skipped > 0 {
    True ->
      list.append(parts, [
        ansi.dim(int.to_string(r.skipped) <> " skipped"),
      ])
    False -> parts
  }

  ansi.dim("(") <> string.join(parts, ansi.dim(", ")) <> ansi.dim(")")
}

// ============================================================================
// Phase 2a: Failures grouped by file
// ============================================================================

fn print_failures_by_file(results: List(TestSuiteResult)) -> Nil {
  let file_failures = collect_failures_by_file(results)

  console.with_group("Failures  " <> ansi.dim("(by file)"), fn() {
    list.each(file_failures, fn(pair) {
      let #(file, failures) = pair
      print_failure_group(util.get_filename(file), failures)
    })
  })
  io.println("")
}

fn collect_failures_by_file(
  results: List(TestSuiteResult),
) -> List(#(String, List(TestResult))) {
  results
  |> list.filter_map(fn(r) {
    let failures = get_failure_results(r.results)
    case failures {
      [] -> Error(Nil)
      _ -> Ok(#(r.file, failures))
    }
  })
}

// ============================================================================
// Phase 2b: Failures grouped by validation kind
// ============================================================================

fn print_failures_by_validation(results: List(TestSuiteResult)) -> Nil {
  let grouped = collect_failures_by_validation(results)

  console.with_group("Failures  " <> ansi.dim("(by validation)"), fn() {
    list.each(grouped, fn(pair) {
      let #(validation, failures) = pair
      print_failure_group(validation, failures)
    })
  })
  io.println("")
}

fn collect_failures_by_validation(
  results: List(TestSuiteResult),
) -> List(#(String, List(TestResult))) {
  let all_failures =
    results |> list.flat_map(fn(r) { get_failure_results(r.results) })

  let grouped =
    list.fold(all_failures, dict.new(), fn(acc, failure) {
      let validation = extract_validation(failure)
      let existing = dict.get(acc, validation) |> result.unwrap([])
      dict.insert(acc, validation, list.append(existing, [failure]))
    })

  grouped
  |> dict.to_list
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}

fn extract_validation(result: TestResult) -> String {
  let name = case result {
    TestFailed(n, _, _) -> n
    _ -> ""
  }

  let known = [
    "canonical_format", "build_hierarchy", "round_trip", "get_string",
    "get_float", "get_bool", "get_list", "get_int", "parse", "print",
  ]

  find_suffix(name, known)
}

fn find_suffix(name: String, suffixes: List(String)) -> String {
  case suffixes {
    [] -> "unknown"
    [suffix, ..rest] ->
      case string.ends_with(name, "_" <> suffix) {
        True -> suffix
        False -> find_suffix(name, rest)
      }
  }
}

// ============================================================================
// Shared: render a group of failures
// ============================================================================

fn print_failure_group(group_title: String, failures: List(TestResult)) -> Nil {
  let count = list.length(failures)
  let title =
    group_title
    <> "  "
    <> ansi.dim(
      "("
      <> int.to_string(count)
      <> " "
      <> pluralize(count, "failure", "failures")
      <> ")",
    )

  console.with_group(title, fn() {
    let #(shown, rest) = list.split(failures, max_failures_per_group)
    list.each(shown, print_single_failure)

    case rest {
      [] -> Nil
      _ -> print_overflow(rest)
    }
  })
  io.println("")
}

fn print_single_failure(result: TestResult) -> Nil {
  case result {
    TestFailed(name, reason, _) -> {
      io.println("    " <> ansi.fg("✖ ", style.Red) <> ansi.bold(name))
      let indent = "      "
      reason
      |> string.split("\n")
      |> list.each(fn(line) { io.println(indent <> line) })
      io.println("")
    }
    _ -> Nil
  }
}

fn print_overflow(rest: List(TestResult)) -> Nil {
  let rest_count = list.length(rest)
  io.println(
    "    "
    <> ansi.fg(
      "… and "
        <> int.to_string(rest_count)
        <> " more "
        <> pluralize(rest_count, "failure", "failures")
        <> ":",
      style.Yellow,
    ),
  )
  list.each(rest, fn(r) {
    case r {
      TestFailed(n, _, _) -> io.println("      " <> ansi.dim("• " <> n))
      _ -> Nil
    }
  })
}

// ============================================================================
// Phase 3: Feature breakdown
// ============================================================================

/// Feature stats for a single feature tag
type FeatureStats {
  FeatureStats(passed: Int, failed: Int, skipped: Int)
}

fn print_feature_breakdown(results: List(TestSuiteResult)) -> Nil {
  let all_case_results =
    results |> list.flat_map(fn(r) { r.results })

  // Collect unique features and their stats
  let feature_stats = collect_feature_stats(all_case_results)

  case dict.is_empty(feature_stats) {
    True -> Nil
    False -> {
      console.with_group("By Feature", fn() {
        feature_stats
        |> dict.to_list
        |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
        |> list.each(fn(pair) {
          let #(feature, stats) = pair
          let total = stats.passed + stats.failed + stats.skipped

          let status_parts = []
          let status_parts = case stats.passed > 0 {
            True ->
              list.append(status_parts, [
                ansi.fg(int.to_string(stats.passed) <> " passed", style.Green),
              ])
            False -> status_parts
          }
          let status_parts = case stats.failed > 0 {
            True ->
              list.append(status_parts, [
                ansi.fg(int.to_string(stats.failed) <> " failed", style.Red),
              ])
            False -> status_parts
          }
          let status_parts = case stats.skipped > 0 {
            True ->
              list.append(status_parts, [
                ansi.dim(int.to_string(stats.skipped) <> " skipped"),
              ])
            False -> status_parts
          }

          let rate = case stats.passed + stats.failed {
            0 -> ansi.dim("—")
            ran ->
              format_pct(stats.passed, int.to_float(ran))
              |> fn(p) {
                case stats.failed > 0 {
                  True -> ansi.fg(p, style.Red)
                  False -> ansi.fg(p, style.Green)
                }
              }
          }

          io.println(
            "  "
            <> util.pad_right(feature, 25)
            <> " "
            <> util.pad_left(int.to_string(total), 4)
            <> " tests  "
            <> rate
            <> "  "
            <> ansi.dim("(")
            <> string.join(status_parts, ansi.dim(", "))
            <> ansi.dim(")"),
          )
        })
      })
      io.println("")
    }
  }
}

fn collect_feature_stats(
  case_results: List(TestCaseResult),
) -> dict.Dict(String, FeatureStats) {
  list.fold(case_results, dict.new(), fn(acc, cr) {
    let features = cr.test_case.features
    case features {
      [] -> acc
      _ ->
        list.fold(features, acc, fn(inner_acc, feature) {
          let current =
            dict.get(inner_acc, feature)
            |> result.unwrap(FeatureStats(passed: 0, failed: 0, skipped: 0))
          let updated = case cr.result {
            TestPassed(_, _) ->
              FeatureStats(..current, passed: current.passed + 1)
            TestFailed(_, _, _) ->
              FeatureStats(..current, failed: current.failed + 1)
            TestSkipped(_, _) ->
              FeatureStats(..current, skipped: current.skipped + 1)
          }
          dict.insert(inner_acc, feature, updated)
        })
    }
  })
}

// ============================================================================
// Phase 4: Summary box
// ============================================================================

fn print_summary(results: List(TestSuiteResult)) -> Nil {
  let total_passed =
    results |> list.map(fn(r) { r.passed }) |> list.fold(0, fn(a, n) { a + n })
  let total_failed =
    results |> list.map(fn(r) { r.failed }) |> list.fold(0, fn(a, n) { a + n })
  let total_skipped =
    results
    |> list.map(fn(r) { r.skipped })
    |> list.fold(0, fn(a, n) { a + n })
  let total = total_passed + total_failed + total_skipped

  let total_f = int.to_float(total)

  let files_count = list.length(results)
  let failed_files = list.count(results, fn(r) { r.failed > 0 })

  let files_note = case failed_files > 0 {
    True -> ", " <> int.to_string(failed_files) <> " with failures"
    False -> ""
  }

  let body =
    "Files:    "
    <> int.to_string(files_count)
    <> files_note
    <> "\n"
    <> "Total:    "
    <> int.to_string(total)
    <> "\n"
    <> "Passed:   "
    <> util.pad_left(int.to_string(total_passed), 4)
    <> "  ("
    <> format_pct(total_passed, total_f)
    <> ")\n"
    <> "Failed:   "
    <> util.pad_left(int.to_string(total_failed), 4)
    <> "  ("
    <> format_pct(total_failed, total_f)
    <> ")\n"
    <> "Skipped:  "
    <> util.pad_left(int.to_string(total_skipped), 4)
    <> "  ("
    <> format_pct(total_skipped, total_f)
    <> ")"

  console.write_box_with_title(body, "Summary")
}

// ============================================================================
// Helpers
// ============================================================================

/// Extract just the TestResult failures from a list of TestCaseResults.
fn get_failure_results(results: List(TestCaseResult)) -> List(TestResult) {
  results
  |> list.filter_map(fn(r) {
    case r.result {
      TestFailed(_, _, _) -> Ok(r.result)
      _ -> Error(Nil)
    }
  })
}

fn format_pct(count: Int, total: Float) -> String {
  case total >. 0.0 {
    True -> {
      let pct = int.to_float(count) *. 100.0 /. total
      let rounded =
        float.round(pct *. 10.0)
        |> int.to_float
        |> fn(x) { x /. 10.0 }
      float.to_string(rounded) <> "%"
    }
    False -> "0%"
  }
}

fn pluralize(count: Int, singular: String, plural: String) -> String {
  case count {
    1 -> singular
    _ -> plural
  }
}
