/// CLI command implementations for CCL test runner
import birch
import cli/flags
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import simplifile
import test_filter
import test_loader
import test_runner.{
  type CCL, type CclImplementation, type Entry, CclImplementation, CclList,
  CclObject, CclString, Entry,
}
import test_types.{
  type FailureGrouping, type ImplementationConfig, type TestCase,
  GroupByFile, GroupByValidation, ImplementationConfig,
}

/// Result type for commands
pub type CommandResult {
  Success
  Failure(message: String)
}

/// Build implementation config from flag values
pub fn build_config(
  functions: List(String),
  behaviors: List(String),
  features: List(String),
  variants: List(String),
) -> ImplementationConfig {
  let final_functions = case functions {
    [] -> ["parse", "print"]
    funcs -> funcs
  }

  ImplementationConfig(
    functions: final_functions,
    behaviors: behaviors,
    variants: variants,
    features: features,
  )
}

/// Run command - executes tests against the implementation
pub fn run_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "Run CCL tests against an implementation.

Executes the test suite and reports results with pass/fail/skip counts.",
  )
  use test_dir <- glint.named_arg("directory")
  use functions <- glint.flag(flags.functions_flag())
  use behaviors <- glint.flag(flags.behaviors_flag())
  use features <- glint.flag(flags.features_flag())
  use variants <- glint.flag(flags.variants_flag())
  use group_by <- glint.flag(flags.group_by_flag())
  use named, _args, flags <- glint.command()

  let dir = test_dir(named)
  let assert Ok(funcs) = functions(flags)
  let assert Ok(behavs) = behaviors(flags)
  let assert Ok(feats) = features(flags)
  let assert Ok(vars) = variants(flags)
  let assert Ok(group_by_str) = group_by(flags)

  let config = build_config(funcs, behavs, feats, vars)
  let grouping = parse_grouping(group_by_str)
  run_tests(dir, config, grouping)
}

/// Parse a grouping string into a FailureGrouping value.
fn parse_grouping(s: String) -> FailureGrouping {
  case string.lowercase(s) {
    "validation" | "kind" -> GroupByValidation
    _ -> GroupByFile
  }
}

/// Run tests and return result
fn run_tests(
  test_dir: String,
  config: ImplementationConfig,
  grouping: FailureGrouping,
) -> CommandResult {
  let impl = mock_implementation()

  case test_runner.run_test_directory(test_dir, config, impl) {
    Ok(results) -> {
      test_runner.print_results(results, config, test_dir, grouping)

      let total_failed =
        results
        |> list.map(fn(r) { r.failed })
        |> list.fold(0, fn(acc, n) { acc + n })

      case total_failed > 0 {
        True -> Failure("Tests failed: " <> int.to_string(total_failed))
        False -> Success
      }
    }
    Error(e) -> {
      birch.error_m("Failed to run tests", [#("error", e)])
      Failure(e)
    }
  }
}

/// List command - lists test files with counts
pub fn list_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "List test files in a directory with test counts.

Displays each JSON test file with its number of tests.",
  )
  use test_dir <- glint.named_arg("directory")
  use named, _args, _flags <- glint.command()

  let dir = test_dir(named)
  list_files(dir)
}

/// List test files with counts
fn list_files(test_dir: String) -> CommandResult {
  case test_loader.list_test_files(test_dir) {
    Ok(files) -> {
      io.println("")
      io.println("CCL Test Files")
      io.println("==============")
      io.println("")

      let total_tests =
        files
        |> list.map(fn(file) {
          let count = get_test_count(file)
          let name = get_filename(file)
          let size = get_file_size(file)
          io.println(
            pad_right(name, 45)
            <> " "
            <> pad_left(int.to_string(count), 5)
            <> " tests  "
            <> size,
          )
          count
        })
        |> list.fold(0, fn(acc, n) { acc + n })

      io.println("")
      io.println(
        "Total: "
        <> int.to_string(list.length(files))
        <> " files, "
        <> int.to_string(total_tests)
        <> " tests",
      )
      io.println("")
      Success
    }
    Error(e) -> Failure(e)
  }
}

/// Stats command - show detailed test suite statistics
pub fn stats_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "Show detailed statistics about the test suite.

Displays counts by validation type, function tags, and behaviors.",
  )
  use test_dir <- glint.named_arg("directory")
  use functions <- glint.flag(flags.functions_flag())
  use behaviors <- glint.flag(flags.behaviors_flag())
  use features <- glint.flag(flags.features_flag())
  use variants <- glint.flag(flags.variants_flag())
  use named, _args, flags <- glint.command()

  let dir = test_dir(named)
  let assert Ok(funcs) = functions(flags)
  let assert Ok(behavs) = behaviors(flags)
  let assert Ok(feats) = features(flags)
  let assert Ok(vars) = variants(flags)

  let config = build_config(funcs, behavs, feats, vars)
  show_stats(dir, config)
}

/// Show detailed statistics
fn show_stats(test_dir: String, config: ImplementationConfig) -> CommandResult {
  case test_loader.list_test_files(test_dir) {
    Ok(files) -> {
      io.println("")
      io.println("CCL Test Suite Statistics")
      io.println("=========================")
      io.println("")

      // Load all tests
      let all_suites: List(#(String, test_types.TestSuite)) =
        files
        |> list.filter_map(fn(file) {
          case test_loader.load_test_file(file) {
            Ok(suite) -> Ok(#(file, suite))
            Error(_) -> Error(Nil)
          }
        })

      let all_tests: List(TestCase) =
        all_suites
        |> list.flat_map(fn(pair: #(String, test_types.TestSuite)) {
          { pair.1 }.tests
        })

      let total_count = list.length(all_tests)

      // Count by validation type
      let validations: dict.Dict(String, List(TestCase)) =
        all_tests
        |> list.group(fn(tc: TestCase) { tc.validation })

      io.println("By Validation Type:")
      validations
      |> dict.to_list
      |> list.each(fn(pair: #(String, List(TestCase))) {
        let #(validation, tests) = pair
        io.println(
          "  "
          <> pad_right(validation, 20)
          <> " "
          <> int.to_string(list.length(tests)),
        )
      })

      io.println("")

      // Count by function
      let function_counts =
        count_tags(all_tests, fn(tc: TestCase) { tc.functions })
      io.println("By Function:")
      function_counts
      |> list.each(fn(pair: #(String, Int)) {
        let #(func, count) = pair
        io.println("  " <> pad_right(func, 20) <> " " <> int.to_string(count))
      })

      io.println("")

      // Count compatible/incompatible
      let compatible =
        all_tests
        |> list.filter(fn(tc) { test_filter.is_compatible(config, tc) })
      let compatible_count = list.length(compatible)
      let skipped_count = total_count - compatible_count

      io.println("Compatibility (with current config):")
      io.println(
        "  "
        <> pad_right("Compatible", 20)
        <> " "
        <> int.to_string(compatible_count),
      )
      io.println(
        "  "
        <> pad_right("Would skip", 20)
        <> " "
        <> int.to_string(skipped_count),
      )

      io.println("")
      io.println(
        "Total: "
        <> int.to_string(list.length(files))
        <> " files, "
        <> int.to_string(total_count)
        <> " tests",
      )
      io.println("")
      Success
    }
    Error(e) -> Failure(e)
  }
}

// Helper functions

fn get_test_count(file: String) -> Int {
  case test_loader.load_test_file(file) {
    Ok(suite) -> list.length(suite.tests)
    Error(_) -> 0
  }
}

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn get_file_size(path: String) -> String {
  case simplifile.file_info(path) {
    Ok(info) -> format_size(info.size)
    Error(_) -> "?"
  }
}

fn format_size(bytes: Int) -> String {
  case bytes {
    b if b < 1024 -> int.to_string(b) <> "B"
    b if b < 1_048_576 -> {
      let kb = b / 1024
      int.to_string(kb) <> "K"
    }
    b -> {
      let mb = b / 1_048_576
      int.to_string(mb) <> "M"
    }
  }
}

fn pad_right(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> s <> string.repeat(" ", width - len)
  }
}

fn pad_left(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> string.repeat(" ", width - len) <> s
  }
}

fn count_tags(
  tests: List(TestCase),
  get_tags: fn(TestCase) -> List(String),
) -> List(#(String, Int)) {
  tests
  |> list.flat_map(get_tags)
  |> list.group(fn(tag) { tag })
  |> dict.to_list
  |> list.map(fn(pair: #(String, List(String))) {
    #(pair.0, list.length(pair.1))
  })
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}

// Mock implementation

fn mock_implementation() -> CclImplementation {
  CclImplementation(
    parse: mock_parse,
    parse_indented: mock_parse_indented,
    print: mock_print,
    filter: mock_filter,
    compose: mock_compose,
    build_hierarchy: mock_build_hierarchy,
    get_string: mock_get_string,
    get_int: mock_get_int,
    get_bool: mock_get_bool,
    get_float: mock_get_float,
    get_list: mock_get_list,
  )
}

fn mock_parse(input: String) -> Result(List(Entry), String) {
  let normalized = string.replace(input, "\r\n", "\n")
  let lines = string.split(normalized, "\n")

  lines
  |> list.filter(fn(line) { !string.is_empty(string.trim(line)) })
  |> list.try_map(parse_line)
}

fn parse_line(line: String) -> Result(Entry, String) {
  case string.split_once(line, " = ") {
    Ok(#(key, value)) -> Ok(Entry(key: key, value: value))
    Error(_) -> {
      case string.split_once(line, "=") {
        Ok(#(key, value)) ->
          Ok(Entry(key: string.trim(key), value: string.trim(value)))
        Error(_) -> Error("Invalid line: " <> line)
      }
    }
  }
}

fn mock_parse_indented(input: String) -> Result(List(Entry), String) {
  // Strip leading indentation then parse normally
  let lines = string.split(input, "\n")
  let dedented =
    lines
    |> list.map(fn(line) { string.trim_start(line) })
    |> string.join("\n")
  mock_parse(dedented)
}

fn mock_filter(entries: List(Entry)) -> List(Entry) {
  // Remove comment entries (key == "/")
  entries
  |> list.filter(fn(e: Entry) { e.key != "/" })
}

fn mock_compose(left: List(Entry), right: List(Entry)) -> List(Entry) {
  // Simple concatenation
  list.append(left, right)
}

fn mock_print(entries: List(Entry)) -> String {
  entries
  |> list.map(fn(e: Entry) { e.key <> " = " <> e.value })
  |> string.join("\n")
}

fn mock_build_hierarchy(entries: List(Entry)) -> CCL {
  entries
  |> list.fold(dict.new(), fn(acc, entry: Entry) {
    dict.insert(acc, entry.key, CclString(entry.value))
  })
}

fn mock_get_string(ccl: CCL, path: List(String)) -> Result(String, String) {
  case path {
    [] -> Error("Empty path")
    [key] -> {
      case dict.get(ccl, key) {
        Ok(CclString(s)) -> Ok(s)
        Ok(CclList([first, ..])) -> Ok(first)
        Ok(_) -> Error("Not a string: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
    [key, ..rest] -> {
      case dict.get(ccl, key) {
        Ok(CclObject(obj)) -> mock_get_string(obj, rest)
        Ok(_) -> Error("Not an object: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
  }
}

fn mock_get_int(ccl: CCL, path: List(String)) -> Result(Int, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case int.parse(str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error("Not an integer: " <> str)
  }
}

fn mock_get_bool(ccl: CCL, path: List(String)) -> Result(Bool, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case string.lowercase(str) {
    "true" -> Ok(True)
    "false" -> Ok(False)
    _ -> Error("Not a boolean: " <> str)
  }
}

fn mock_get_float(ccl: CCL, path: List(String)) -> Result(Float, String) {
  use str <- result.try(mock_get_string(ccl, path))
  case float.parse(str) {
    Ok(f) -> Ok(f)
    Error(_) -> {
      case int.parse(str) {
        Ok(n) -> Ok(int.to_float(n))
        Error(_) -> Error("Not a float: " <> str)
      }
    }
  }
}

fn mock_get_list(ccl: CCL, path: List(String)) -> Result(List(String), String) {
  case path {
    [] -> Error("Empty path")
    [key] -> {
      case dict.get(ccl, key) {
        Ok(CclList(l)) -> Ok(l)
        Ok(CclString(s)) -> Ok([s])
        Ok(_) -> Error("Not a list: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
    [key, ..rest] -> {
      case dict.get(ccl, key) {
        Ok(CclObject(obj)) -> mock_get_list(obj, rest)
        Ok(_) -> Error("Not an object: " <> key)
        Error(_) -> Error("Key not found: " <> key)
      }
    }
  }
}
