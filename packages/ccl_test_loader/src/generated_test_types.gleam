/// Types and decoders for the official CCL test data generated flat format
/// Based on schema: ccl-test-data/schemas/generated-format.json
///
/// This module supports the official test format with:
/// - Direct arrays for functions, features, behaviors, variants (not tag-prefixed)
/// - Conflicts object with typed arrays
/// - inputs array (not single input)
/// - validation field identifying the test type
import ccl_types
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/string
import simplifile

// === OFFICIAL CCL FUNCTION NAMES ===
// Per generated-format.json schema

pub const function_parse = "parse"

pub const function_parse_indented = "parse_indented"

pub const function_filter = "filter"

pub const function_compose = "compose"

pub const function_build_hierarchy = "build_hierarchy"

pub const function_get_string = "get_string"

pub const function_get_int = "get_int"

pub const function_get_bool = "get_bool"

pub const function_get_float = "get_float"

pub const function_get_list = "get_list"

pub const function_print = "print"

pub const function_canonical_format = "canonical_format"

pub const function_load = "load"

pub const function_round_trip = "round_trip"

// === OFFICIAL BEHAVIOR NAMES ===

pub const behavior_boolean_strict = "boolean_strict"

pub const behavior_boolean_lenient = "boolean_lenient"

pub const behavior_crlf_preserve_literal = "crlf_preserve_literal"

pub const behavior_crlf_normalize_to_lf = "crlf_normalize_to_lf"

pub const behavior_tabs_as_content = "tabs_as_content"

pub const behavior_tabs_as_whitespace = "tabs_as_whitespace"

pub const behavior_indent_spaces = "indent_spaces"

pub const behavior_indent_tabs = "indent_tabs"

pub const behavior_list_coercion_enabled = "list_coercion_enabled"

pub const behavior_list_coercion_disabled = "list_coercion_disabled"

pub const behavior_array_order_insertion = "array_order_insertion"

pub const behavior_array_order_lexicographic = "array_order_lexicographic"

pub const behavior_toplevel_indent_strip = "toplevel_indent_strip"

pub const behavior_toplevel_indent_preserve = "toplevel_indent_preserve"

// === OFFICIAL VARIANT NAMES ===

pub const variant_proposed_behavior = "proposed_behavior"

pub const variant_reference_compliant = "reference_compliant"

// === OFFICIAL FEATURE NAMES ===

pub const feature_comments = "comments"

pub const feature_empty_keys = "empty_keys"

pub const feature_multiline = "multiline"

pub const feature_unicode = "unicode"

pub const feature_whitespace = "whitespace"

// === GENERATED FORMAT TYPES ===

/// Conflicts specification per test
/// Indicates which options are mutually exclusive with this test
pub type Conflicts {
  Conflicts(
    functions: List(String),
    behaviors: List(String),
    variants: List(String),
    features: List(String),
  )
}

/// Empty conflicts for tests with no conflicts
pub fn empty_conflicts() -> Conflicts {
  Conflicts(functions: [], behaviors: [], variants: [], features: [])
}

/// Expected result structure - varies by validation type
pub type ExpectedResult {
  /// For parse validation - list of entries
  ExpectedEntries(count: Int, entries: List(ccl_types.Entry))
  /// For build_hierarchy validation - nested object
  ExpectedObject(count: Int, object: dict.Dict(String, dynamic.Dynamic))
  /// For typed access validation (get_string, get_int, etc.)
  ExpectedValue(count: Int, value: dynamic.Dynamic)
  /// For list access validation
  ExpectedList(count: Int, list_values: List(dynamic.Dynamic))
  /// For print/canonical_format validation
  ExpectedText(count: Int, text: String)
  /// For algebraic property tests
  ExpectedBoolean(count: Int, boolean: Bool)
  /// For error tests
  ExpectedError(count: Int)
  /// Count only (no specific expected value)
  ExpectedCountOnly(count: Int)
}

/// A single test case in the generated flat format
pub type GeneratedTestCase {
  GeneratedTestCase(
    /// Unique test name (source_name + validation function)
    name: String,
    /// CCL input text(s) to be tested
    inputs: List(String),
    /// Single CCL function to validate
    validation: String,
    /// Expected result
    expected: ExpectedResult,
    /// Arguments for typed access functions (optional)
    args: Option(List(String)),
    /// CCL functions tested by this test
    functions: List(String),
    /// Implementation behavior choices required
    behaviors: List(String),
    /// Specification variants
    variants: List(String),
    /// Language features exercised (informational only)
    features: List(String),
    /// Mutually exclusive options
    conflicts: Conflicts,
    /// Original source test name for traceability
    source_test: Option(String),
    /// Whether this test should produce an error
    expect_error: Bool,
    /// Expected error type for error tests
    error_type: Option(String),
  )
}

/// A test suite in the generated flat format
pub type GeneratedTestSuite {
  GeneratedTestSuite(tests: List(GeneratedTestCase))
}

// === DECODERS ===

/// Decode conflicts object
fn conflicts_decoder() -> decode.Decoder(Conflicts) {
  decode.one_of(
    // Primary decoder: full conflicts object
    {
      use functions <- decode.optional_field(
        "functions",
        [],
        decode.list(decode.string),
      )
      use behaviors <- decode.optional_field(
        "behaviors",
        [],
        decode.list(decode.string),
      )
      use variants <- decode.optional_field(
        "variants",
        [],
        decode.list(decode.string),
      )
      use features <- decode.optional_field(
        "features",
        [],
        decode.list(decode.string),
      )
      decode.success(Conflicts(
        functions: functions,
        behaviors: behaviors,
        variants: variants,
        features: features,
      ))
    },
    // Fallback: return empty conflicts if decoding fails
    [decode.success(empty_conflicts())],
  )
}

/// Decode entry for parse results
fn entry_decoder() -> decode.Decoder(ccl_types.Entry) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(ccl_types.Entry(key, value))
}

/// Decode expected result based on validation type
fn expected_decoder(validation: String) -> decode.Decoder(ExpectedResult) {
  use count <- decode.field("count", decode.int)

  case validation {
    "parse" | "parse_indented" | "filter" -> {
      use entries <- decode.optional_field(
        "entries",
        [],
        decode.list(entry_decoder()),
      )
      decode.success(ExpectedEntries(count: count, entries: entries))
    }

    "build_hierarchy" -> {
      use object <- decode.optional_field(
        "object",
        dict.new(),
        decode.dict(decode.string, decode.dynamic),
      )
      decode.success(ExpectedObject(count: count, object: object))
    }

    "get_string" | "get_int" | "get_bool" | "get_float" -> {
      // For typed access, we decode the value field as dynamic
      // If missing, we'll use an empty dynamic placeholder
      use raw_value <- decode.field("value", decode.dynamic)
      decode.success(ExpectedValue(count: count, value: raw_value))
    }

    "get_list" -> {
      use list_values <- decode.optional_field(
        "list",
        [],
        decode.list(decode.dynamic),
      )
      decode.success(ExpectedList(count: count, list_values: list_values))
    }

    "print" | "canonical_format" -> {
      use text <- decode.optional_field("text", "", decode.string)
      decode.success(ExpectedText(count: count, text: text))
    }

    "round_trip" | "compose_associative" | "identity_left" | "identity_right" -> {
      use boolean <- decode.optional_field("boolean", True, decode.bool)
      decode.success(ExpectedBoolean(count: count, boolean: boolean))
    }

    _ -> {
      // For unknown validation types, check for error flag
      use error <- decode.optional_field("error", False, decode.bool)
      case error {
        True -> decode.success(ExpectedError(count: count))
        False -> decode.success(ExpectedCountOnly(count: count))
      }
    }
  }
}

/// Decode a single test case
fn test_case_decoder() -> decode.Decoder(GeneratedTestCase) {
  use name <- decode.field("name", decode.string)
  use inputs <- decode.field("inputs", decode.list(decode.string))
  use validation <- decode.field("validation", decode.string)
  use functions <- decode.field("functions", decode.list(decode.string))
  use behaviors <- decode.field("behaviors", decode.list(decode.string))
  use variants <- decode.field("variants", decode.list(decode.string))
  use features <- decode.field("features", decode.list(decode.string))
  use conflicts <- decode.optional_field(
    "conflicts",
    empty_conflicts(),
    conflicts_decoder(),
  )
  use args <- decode.optional_field(
    "args",
    None,
    decode.optional(decode.list(decode.string)),
  )
  use source_test <- decode.optional_field(
    "source_test",
    None,
    decode.optional(decode.string),
  )
  use expect_error <- decode.optional_field("expect_error", False, decode.bool)
  use error_type <- decode.optional_field(
    "error_type",
    None,
    decode.optional(decode.string),
  )

  // Now decode expected with validation context
  use expected <- decode.field("expected", expected_decoder(validation))

  decode.success(GeneratedTestCase(
    name: name,
    inputs: inputs,
    validation: validation,
    expected: expected,
    args: args,
    functions: functions,
    behaviors: behaviors,
    variants: variants,
    features: features,
    conflicts: conflicts,
    source_test: source_test,
    expect_error: expect_error,
    error_type: error_type,
  ))
}

/// Decode a test suite
fn test_suite_decoder() -> decode.Decoder(GeneratedTestSuite) {
  use tests <- decode.field("tests", decode.list(test_case_decoder()))
  decode.success(GeneratedTestSuite(tests: tests))
}

/// Load a generated test suite from a JSON file
pub fn load_generated_test_suite(
  file_path: String,
) -> Result(GeneratedTestSuite, String) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(_) { "Could not read file: " <> file_path }),
  )

  json.parse(content, test_suite_decoder())
  |> result.map_error(fn(err) {
    "JSON parsing failed for " <> file_path <> ": " <> string.inspect(err)
  })
}

/// Load all generated test suites from a directory
pub fn load_all_generated_tests(
  directory: String,
) -> Result(List(GeneratedTestCase), String) {
  use files <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(fn(_) { "Could not read directory: " <> directory }),
  )

  let json_files =
    files
    |> list.filter(fn(f) { string.ends_with(f, ".json") })
    |> list.map(fn(f) { directory <> "/" <> f })

  let results =
    list.filter_map(json_files, fn(path) {
      case load_generated_test_suite(path) {
        Ok(suite) -> Ok(suite.tests)
        Error(_) -> Error(Nil)
      }
    })

  Ok(list.flatten(results))
}

/// Get the primary input for a test case (first element of inputs array)
pub fn get_primary_input(test_case: GeneratedTestCase) -> String {
  case test_case.inputs {
    [first, ..] -> first
    [] -> ""
  }
}

/// Get the assertion count from expected result
pub fn get_expected_count(expected: ExpectedResult) -> Int {
  case expected {
    ExpectedEntries(count, _) -> count
    ExpectedObject(count, _) -> count
    ExpectedValue(count, _) -> count
    ExpectedList(count, _) -> count
    ExpectedText(count, _) -> count
    ExpectedBoolean(count, _) -> count
    ExpectedError(count) -> count
    ExpectedCountOnly(count) -> count
  }
}
