/// Test report rendering for CLI output
///
/// Hybrid approach: uses birch grouping for visual hierarchy and boxes for
/// framing. Direct IO for content where birch's semantic types don't fit.
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
import test_types.{
  type FailureGrouping, type ImplementationConfig, type TestResult,
  type TestSuiteResult, GroupByFile, GroupByValidation, TestFailed,
}

// ============================================================================
// ANSI helpers (for content birch doesn't style)
// ============================================================================

const reset = "\u{001b}[0m"

const bold = "\u{001b}[1m"

const dim = "\u{001b}[2m"

const green = "\u{001b}[32m"

const red = "\u{001b}[31m"

const yellow = "\u{001b}[33m"

/// Maximum number of failures to show per group in the detail section.
/// Remaining failures are listed by name only.
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
  let has_failures =
    list.any(results, fn(r) { r.failed > 0 })
  case has_failures {
    False -> Nil
    True ->
      case grouping {
        GroupByFile -> print_failures_by_file(results)
        GroupByValidation -> print_failures_by_validation(results)
      }
  }

  // Phase 3: summary box
  print_summary(results)
}

// ============================================================================
// Phase 1: Compact overview
// ============================================================================

fn print_results_overview(results: List(TestSuiteResult)) -> Nil {
  console.with_group("Results", fn() {
    list.each(results, print_file_line)
  })
  io.println("")
}

fn print_file_line(r: TestSuiteResult) -> Nil {
  let name = get_filename(r.file)
  let counts = format_counts_inline(r)

  let icon = case r.failed > 0 {
    True -> red <> "✖" <> reset
    False -> green <> "✔" <> reset
  }

  io.println("  " <> icon <> " " <> name <> "  " <> counts)
}

fn format_counts_inline(r: TestSuiteResult) -> String {
  let parts = []

  let parts = case r.passed > 0 {
    True ->
      list.append(parts, [
        green <> int.to_string(r.passed) <> " passed" <> reset,
      ])
    False -> parts
  }

  let parts = case r.failed > 0 {
    True ->
      list.append(parts, [
        red <> int.to_string(r.failed) <> " failed" <> reset,
      ])
    False -> parts
  }

  let parts = case r.skipped > 0 {
    True ->
      list.append(parts, [
        dim <> int.to_string(r.skipped) <> " skipped" <> reset,
      ])
    False -> parts
  }

  dim
  <> "("
  <> reset
  <> string.join(parts, dim <> ", " <> reset)
  <> dim
  <> ")"
  <> reset
}

// ============================================================================
// Phase 2a: Failures grouped by file
// ============================================================================

fn print_failures_by_file(results: List(TestSuiteResult)) -> Nil {
  let file_failures = collect_failures_by_file(results)

  console.with_group("Failures  " <> dim <> "(by file)" <> reset, fn() {
    list.each(file_failures, fn(pair) {
      let #(file, failures) = pair
      let name = get_filename(file)
      print_failure_group(name, failures)
    })
  })
  io.println("")
}

fn collect_failures_by_file(
  results: List(TestSuiteResult),
) -> List(#(String, List(TestResult))) {
  results
  |> list.filter_map(fn(r) {
    let failures = get_failures(r.results)
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

  console.with_group(
    "Failures  " <> dim <> "(by validation)" <> reset,
    fn() {
      list.each(grouped, fn(pair) {
        let #(validation, failures) = pair
        print_failure_group(validation, failures)
      })
    },
  )
  io.println("")
}

/// Collect all failures across all files, grouped by validation kind.
/// Returns a sorted list of (validation_kind, failures) pairs.
fn collect_failures_by_validation(
  results: List(TestSuiteResult),
) -> List(#(String, List(TestResult))) {
  // Collect all failures with their validation kind
  let all_failures =
    results
    |> list.flat_map(fn(r) { get_failures(r.results) })

  // Group by extracted validation kind
  let grouped =
    list.fold(all_failures, dict.new(), fn(acc, failure) {
      let validation = extract_validation(failure)
      let existing = dict.get(acc, validation) |> result.unwrap([])
      dict.insert(acc, validation, list.append(existing, [failure]))
    })

  // Sort by validation name for consistent output
  grouped
  |> dict.to_list
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}

/// Extract validation kind from a test result name.
/// Test names follow the pattern `test_description_validation`,
/// e.g. `deep_nested_objects_parse`, `round_trip_basic_round_trip`.
fn extract_validation(result: TestResult) -> String {
  let name = case result {
    TestFailed(n, _, _) -> n
    _ -> ""
  }

  // Known validation suffixes, longest first to match correctly
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
// Shared: render a group of failures (used by both grouping modes)
// ============================================================================

fn print_failure_group(
  group_title: String,
  failures: List(TestResult),
) -> Nil {
  let count = list.length(failures)
  let title =
    group_title
    <> "  "
    <> dim
    <> "("
    <> int.to_string(count)
    <> " "
    <> pluralize(count, "failure", "failures")
    <> ")"
    <> reset

  console.with_group(title, fn() {
    let #(shown, rest) = list.split(failures, max_failures_per_group)

    list.each(shown, fn(f) { print_single_failure(f) })

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
      io.println("    " <> red <> "✖ " <> reset <> bold <> name <> reset)

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
    <> yellow
    <> "… and "
    <> int.to_string(rest_count)
    <> " more "
    <> pluralize(rest_count, "failure", "failures")
    <> ":"
    <> reset,
  )
  list.each(rest, fn(r) {
    case r {
      TestFailed(n, _, _) -> io.println("      " <> dim <> "• " <> n <> reset)
      _ -> Nil
    }
  })
}

// ============================================================================
// Phase 3: Summary box
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

  let pass_pct = format_pct(total_passed, total_f)
  let fail_pct = format_pct(total_failed, total_f)
  let skip_pct = format_pct(total_skipped, total_f)

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
    <> pad_left(int.to_string(total_passed), 4)
    <> "  ("
    <> pass_pct
    <> ")\n"
    <> "Failed:   "
    <> pad_left(int.to_string(total_failed), 4)
    <> "  ("
    <> fail_pct
    <> ")\n"
    <> "Skipped:  "
    <> pad_left(int.to_string(total_skipped), 4)
    <> "  ("
    <> skip_pct
    <> ")"

  console.write_box_with_title(body, "Summary")
}

// ============================================================================
// Helpers
// ============================================================================

fn get_failures(results: List(TestResult)) -> List(TestResult) {
  list.filter(results, fn(r) {
    case r {
      TestFailed(_, _, _) -> True
      _ -> False
    }
  })
}

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn pad_left(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> string.repeat(" ", width - len) <> s
  }
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
