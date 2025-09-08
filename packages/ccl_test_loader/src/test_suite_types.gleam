import ccl_types
import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile
import test_config.{type TestConfig}

pub type TestCase {
  TestCase(
    name: String,
    description: String,
    input: String,
    expected: List(ccl_types.Entry),
    tags: List(String),
  )
}

pub type ErrorTestCase {
  ErrorTestCase(
    name: String,
    description: String,
    input: String,
    expected_error: Bool,
    error_message: String,
    tags: List(String),
  )
}

pub type TypedValue {
  StringVal(String)
  IntVal(Int)
  FloatVal(Float)
  BoolVal(Bool)
  EmptyVal
}

// === NEW VALIDATION TYPES FOR MIGRATION ===

/// Node types from ccl.gleam
pub type NodeType {
  SingleValue
  ListValue  
  ObjectValue
  Missing
}

/// Property specifications for property tests
pub type AssociativitySpec {
  AssociativitySpec(
    property: String,
    should_be_equal: Bool
  )
}

pub type RoundTripSpec {
  RoundTripSpec(
    property: String  // "identity"
  )
}

/// New validation structure for both API and property tests
pub type TestValidations {
  TestValidations(
    // API test validations
    parse: Option(List(ccl_types.Entry)),
    make_objects: Option(ccl_types.CCL),
    get_string: Option(String),
    get_list: Option(List(String)), 
    node_type: Option(NodeType),
    
    // Property test validations
    associativity: Option(AssociativitySpec),
    round_trip: Option(RoundTripSpec)
  )
}

pub type ParseOptions {
  ParseOptions(parse_integers: Bool, parse_floats: Bool, parse_booleans: Bool)
}

// Types for pretty printer tests
pub type PrettyPrintTestCase {
  PrettyPrintTestCase(
    name: String,
    property: String,
    // "round_trip", "canonical_format", "deterministic"
    input: String,
    expected_canonical: String,
    tags: List(String),
  )
}

// Test discovery functions - configurable
pub fn discover_json_test_files(config: TestConfig) -> List(String) {
  test_config.discover_test_files(config)
}

/// API test file paths for new validation format
pub fn api_test_paths() -> List(String) {
  let base_path = "../../../ccl-test-data/tests"
  [
    base_path <> "/api-essential-parsing.json",
    base_path <> "/api-comprehensive-parsing.json", 
    base_path <> "/api-comments.json",
    base_path <> "/api-processing.json",
    base_path <> "/api-object-construction.json",
    base_path <> "/api-dotted-keys.json",
    base_path <> "/api-typed-access.json",
    base_path <> "/api-errors.json"
  ]
}

/// Property test file paths for new validation format
pub fn property_test_paths() -> List(String) {
  let base_path = "../../../ccl-test-data/tests"
  [
    base_path <> "/property-algebraic.json",
    base_path <> "/property-round-trip.json"
  ]
}

/// New test suite structure for validation format
pub type NewTestSuite {
  NewTestSuite(
    suite: String,
    version: String,
    description: Option(String),
    tests: List(NewUnifiedTestCase)
  )
}

/// Load a test suite using the new validation format
pub fn load_new_test_suite(filename: String) -> Result(NewTestSuite, String) {
  case simplifile.read(filename) {
    Ok(content) -> {
      case json.parse(content, new_test_suite_decoder()) {
        Ok(suite) -> Ok(suite)
        Error(err) ->
          Error(
            "Invalid JSON format in " <> filename <> ": " <> string.inspect(err),
          )
      }
    }
    Error(err) ->
      Error("Could not read file " <> filename <> ": " <> string.inspect(err))
  }
}

/// Safe version that returns empty suite on error
pub fn load_new_test_suite_safe(filename: String) -> NewTestSuite {
  case load_new_test_suite(filename) {
    Ok(suite) -> suite
    Error(_) ->
      NewTestSuite(
        suite: "Empty Suite",
        version: "1.0",
        description: None,
        tests: [],
      )
  }
}

pub fn load_and_validate_test_suite(
  filename: String,
) -> Result(TestSuite, String) {
  case simplifile.read(filename) {
    Ok(content) -> {
      case json.parse(content, test_suite_decoder()) {
        Ok(suite) -> Ok(suite)
        Error(err) ->
          Error(
            "Invalid JSON format in " <> filename <> ": " <> string.inspect(err),
          )
      }
    }
    Error(err) ->
      Error("Could not read file " <> filename <> ": " <> string.inspect(err))
  }
}

pub fn load_test_suite_safe(filename: String) -> TestSuite {
  case load_and_validate_test_suite(filename) {
    Ok(suite) -> suite
    Error(_) ->
      TestSuite(
        suite: "Empty Suite",
        version: "1.0",
        description: None,
        tests: [],
      )
  }
}

/// Load all tests from new format JSON files
fn load_all_new_tests() -> List(NewUnifiedTestCase) {
  // Load from both API and property test paths
  let api_files = api_test_paths()
  let property_files = property_test_paths()
  let all_files = list.append(api_files, property_files)
  
  all_files
  |> list.filter_map(fn(path) {
    case load_new_test_suite(path) {
      Ok(suite) -> Ok(suite.tests)
      Error(_) -> Error(Nil)
    }
  })
  |> list.flatten
}

/// Load pretty printer test file
fn load_pretty_printer_test_file(path: String) -> List(PrettyPrintTestCase) {
  // For now, return empty list - this would need proper implementation
  // to load from JSON files with pretty printer test format
  []
}

pub fn get_pretty_printer_tests(path: String) -> List(PrettyPrintTestCase) {
  load_pretty_printer_test_file(path)
}

pub fn get_tests_by_tags(
  required_tags: List(String),
  config: TestConfig,
) -> List(TestCase) {
  get_all_tests(config)
  |> list.filter(fn(test_case) {
    list.all(required_tags, fn(tag) { list.contains(test_case.meta.tags, tag) })
  })
  |> list.filter(not_error_test)
  |> list.filter_map(convert_to_basic_test_case)
}

pub fn get_regular_tests(config: TestConfig) -> List(TestCase) {
  get_all_tests(config)
  |> list.filter(not_error_test)
  |> list.filter_map(convert_to_basic_test_case)
}

pub fn get_all_error_tests(config: TestConfig) -> List(ErrorTestCase) {
  get_all_tests(config)
  |> list.filter_map(convert_to_error_test_case)
}

pub fn get_tests_by_suite_name(
  suite_name: String,
  config: TestConfig,
) -> List(TestCase) {
  discover_json_test_files(config)
  |> list.filter_map(fn(file) {
    case load_and_validate_test_suite(file) {
      Ok(suite) if suite.suite == suite_name -> Ok(suite.tests)
      _ -> Error(Nil)
    }
  })
  |> list.flatten
  |> list.filter(not_error_test)
  |> list.filter_map(convert_to_basic_test_case)
}

pub fn get_all_available_tests(
  config: TestConfig,
) -> dict.Dict(String, List(UnifiedTestCase)) {
  discover_json_test_files(config)
  |> list.map(fn(file) {
    let suite = load_test_suite_safe(file)
    #(suite.suite, suite.tests)
  })
  |> dict.from_list
}

pub fn get_test_suite_summary(config: TestConfig) -> String {
  let suites = get_all_available_tests(config)
  let total_tests =
    dict.values(suites)
    |> list.map(list.length)
    |> list.fold(0, fn(acc, x) { acc + x })

  "Found "
  <> string.inspect(dict.size(suites))
  <> " test suites with "
  <> string.inspect(total_tests)
  <> " total tests"
}


fn get_all_tests(config: TestConfig) -> List(UnifiedTestCase) {
  discover_json_test_files(config)
  |> list.map(load_test_suite_safe)
  |> list.map(fn(suite) { suite.tests })
  |> list.flatten
}

// JSON decoders
fn entry_decoder() -> decode.Decoder(ccl_types.Entry) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(ccl_types.Entry(key, value))
}

// Decoder for the expected_typed field (dict of path -> typed value)
fn typed_values_decoder() -> decode.Decoder(List(#(String, TypedValue))) {
  let dict_decoder = decode.dict(decode.string, typed_value_decoder())
  use dict_data <- decode.then(dict_decoder)
  decode.success(dict.to_list(dict_data))
}

// Decoder for a single typed value object
fn typed_value_decoder() -> decode.Decoder(TypedValue) {
  use type_name <- decode.field("type", decode.string)
  case type_name {
    "StringVal" -> {
      use value <- decode.field("value", decode.string)
      decode.success(StringVal(value))
    }
    "IntVal" -> {
      use value <- decode.field("value", decode.int)
      decode.success(IntVal(value))
    }
    "FloatVal" -> {
      use value <- decode.field("value", decode.float)
      decode.success(FloatVal(value))
    }
    "BoolVal" -> {
      use value <- decode.field("value", decode.bool)
      decode.success(BoolVal(value))
    }
    "EmptyVal" -> decode.success(EmptyVal)
    _ -> {
      // For unknown type, just return a StringVal as fallback
      decode.success(StringVal("unknown"))
    }
  }
}

// Test suite types and decoders

pub type TestMetadata {
  TestMetadata(tags: List(String), level: Int)
}

// Unified test suite structure
pub type TestSuite {
  TestSuite(
    suite: String,
    version: String,
    description: Option(String),
    tests: List(UnifiedTestCase),
  )
}

pub type UnifiedTestCase {
  UnifiedTestCase(
    name: String,
    input: String,
    expected: Option(List(ccl_types.Entry)),
    expected_flat: Option(List(ccl_types.Entry)),
    expected_nested: Option(dict.Dict(String, String)),
    expected_typed: Option(List(#(String, TypedValue))),
    expected_error: Option(Bool),
    error_message: Option(String),
    parse_options: Option(ParseOptions),
    api_calls: Option(List(String)),
    meta: TestMetadata,
  )
}

/// New unified test case for validation-based format
pub type NewUnifiedTestCase {
  NewUnifiedTestCase(
    name: String,
    input: String,
    validations: TestValidations,
    meta: TestMetadata
  )
}

// Helper functions
fn is_some(option: Option(a)) -> Bool {
  case option {
    Some(_) -> True
    None -> False
  }
}

fn not_error_test(test_case: UnifiedTestCase) -> Bool {
  case test_case.expected_error {
    Some(_) -> False
    // This is an error test
    None -> True
    // This is not an error test
  }
}

fn meta_decoder() -> decode.Decoder(TestMetadata) {
  use tags <- decode.field("tags", decode.list(decode.string))
  use level <- decode.field("level", decode.int)
  decode.success(TestMetadata(tags: tags, level: level))
}

fn test_suite_decoder() -> decode.Decoder(TestSuite) {
  use suite <- decode.field("suite", decode.string)
  use version <- decode.field("version", decode.string)
  use tests <- decode.field("tests", decode.list(unified_test_case_decoder()))
  decode.success(TestSuite(
    suite: suite,
    version: version,
    description: None,
    tests: tests,
  ))
}

fn unified_test_case_decoder() -> decode.Decoder(UnifiedTestCase) {
  decode.one_of(level4_typed_with_options_test_decoder(), [
    level4_typed_test_decoder(),
    level3_object_test_decoder(),
    level12_basic_test_decoder(),
    error_test_decoder(),
  ])
}

// Level 4 with parse_options: Typed parsing tests that have custom parse options
fn level4_typed_with_options_test_decoder() -> decode.Decoder(UnifiedTestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_flat <- decode.field(
    "expected_flat",
    decode.list(entry_decoder()),
  )
  use expected_typed <- decode.field("expected_typed", typed_values_decoder())
  use parse_options <- decode.field("parse_options", parse_options_decoder())
  use meta <- decode.field("meta", meta_decoder())

  decode.success(UnifiedTestCase(
    name: name,
    input: input,
    expected: None,
    expected_flat: Some(expected_flat),
    expected_nested: None,
    expected_typed: Some(expected_typed),
    expected_error: None,
    error_message: None,
    parse_options: Some(parse_options),
    api_calls: None,
    meta: meta,
  ))
}

// Level 4: Typed parsing tests (has expected_typed field, no custom parse_options)
fn level4_typed_test_decoder() -> decode.Decoder(UnifiedTestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_flat <- decode.field(
    "expected_flat",
    decode.list(entry_decoder()),
  )
  use expected_typed <- decode.field("expected_typed", typed_values_decoder())
  use meta <- decode.field("meta", meta_decoder())

  decode.success(UnifiedTestCase(
    name: name,
    input: input,
    expected: None,
    expected_flat: Some(expected_flat),
    expected_nested: None,
    expected_typed: Some(expected_typed),
    expected_error: None,
    error_message: None,
    parse_options: Some(ParseOptions(
      parse_integers: True,
      parse_floats: True,
      parse_booleans: True,
    )),
    api_calls: None,
    meta: meta,
  ))
}

// Level 3: Object construction tests (has expected_flat and expected_nested)
fn level3_object_test_decoder() -> decode.Decoder(UnifiedTestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_flat <- decode.field(
    "expected_flat",
    decode.list(entry_decoder()),
  )
  use meta <- decode.field("meta", meta_decoder())

  // Skip expected_nested for now since it's a complex nested structure
  // The conversion function will handle Level 3 detection via expected_flat + level
  decode.success(UnifiedTestCase(
    name: name,
    input: input,
    expected: None,
    expected_flat: Some(expected_flat),
    expected_nested: None,
    // Skip complex nested decoding for now
    expected_typed: None,
    expected_error: None,
    error_message: None,
    parse_options: None,
    api_calls: None,
    meta: meta,
  ))
}

// Level 1-2: Basic parsing tests (has expected field)
fn level12_basic_test_decoder() -> decode.Decoder(UnifiedTestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use expected <- decode.field("expected", decode.list(entry_decoder()))
  use meta <- decode.field("meta", meta_decoder())

  decode.success(UnifiedTestCase(
    name: name,
    input: input,
    expected: Some(expected),
    expected_flat: None,
    expected_nested: None,
    expected_typed: None,
    expected_error: None,
    error_message: None,
    parse_options: None,
    api_calls: None,
    meta: meta,
  ))
}

// Error tests (has expected_error field)
fn error_test_decoder() -> decode.Decoder(UnifiedTestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_error <- decode.field("expected_error", decode.bool)
  use error_message <- decode.field("error_message", decode.string)
  use meta <- decode.field("meta", meta_decoder())

  decode.success(UnifiedTestCase(
    name: name,
    input: input,
    expected: None,
    expected_flat: None,
    expected_nested: None,
    expected_typed: None,
    expected_error: Some(expected_error),
    error_message: Some(error_message),
    parse_options: None,
    api_calls: None,
    meta: meta,
  ))
}

fn parse_options_decoder() -> decode.Decoder(ParseOptions) {
  use parse_integers <- decode.field("parse_integers", decode.bool)
  use parse_floats <- decode.field("parse_floats", decode.bool)
  use parse_booleans <- decode.field("parse_booleans", decode.bool)

  decode.success(ParseOptions(
    parse_integers: parse_integers,
    parse_floats: parse_floats,
    parse_booleans: parse_booleans,
  ))
}


// === NEW JSON DECODERS FOR VALIDATION FORMAT ===

/// Decoder for NodeType values
fn node_type_decoder() -> decode.Decoder(NodeType) {
  use node_type_str <- decode.then(decode.string)
  case node_type_str {
    "SingleValue" -> decode.success(SingleValue)
    "ListValue" -> decode.success(ListValue)  
    "ObjectValue" -> decode.success(ObjectValue)
    "Missing" -> decode.success(Missing)
    _ -> decode.success(Missing) // Default to Missing for unknown values
  }
}

/// Decoder for AssociativitySpec
fn associativity_decoder() -> decode.Decoder(AssociativitySpec) {
  use property <- decode.field("property", decode.string)
  use should_be_equal <- decode.field("should_be_equal", decode.bool)
  decode.success(AssociativitySpec(
    property: property,
    should_be_equal: should_be_equal
  ))
}

/// Decoder for RoundTripSpec  
fn round_trip_decoder() -> decode.Decoder(RoundTripSpec) {
  use property <- decode.field("property", decode.string)
  decode.success(RoundTripSpec(property: property))
}

/// Decoder for CCL objects - simplified version
fn ccl_decoder() -> decode.Decoder(ccl_types.CCL) {
  // For now, create empty CCL - this will need proper implementation
  decode.success(ccl_types.CCL(dict.new()))
}

/// Decoder for the new validation structure
fn validations_decoder() -> decode.Decoder(TestValidations) {
  use parse_opt <- decode.optional_field("parse", None, decode.optional(decode.list(entry_decoder())))
  use make_objects_opt <- decode.optional_field("make_objects", None, decode.optional(ccl_decoder()))
  use get_string_opt <- decode.optional_field("get_string", None, decode.optional(decode.string))
  use get_list_opt <- decode.optional_field("get_list", None, decode.optional(decode.list(decode.string)))
  use node_type_opt <- decode.optional_field("node_type", None, decode.optional(node_type_decoder()))
  use associativity_opt <- decode.optional_field("associativity", None, decode.optional(associativity_decoder()))
  use round_trip_opt <- decode.optional_field("round_trip", None, decode.optional(round_trip_decoder()))
  
  decode.success(TestValidations(
    parse: parse_opt,
    make_objects: make_objects_opt,
    get_string: get_string_opt,
    get_list: get_list_opt,
    node_type: node_type_opt,
    associativity: associativity_opt,
    round_trip: round_trip_opt
  ))
}

/// Decoder for new unified test case format
fn new_unified_test_case_decoder() -> decode.Decoder(NewUnifiedTestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use validations <- decode.field("validations", validations_decoder())
  use meta <- decode.field("meta", meta_decoder())
  
  decode.success(NewUnifiedTestCase(
    name: name,
    input: input,
    validations: validations,
    meta: meta
  ))
}

/// Decoder for new test suite format
fn new_test_suite_decoder() -> decode.Decoder(NewTestSuite) {
  use suite <- decode.field("suite", decode.string)
  use version <- decode.field("version", decode.string)
  use tests <- decode.field("tests", decode.list(new_unified_test_case_decoder()))
  decode.success(NewTestSuite(
    suite: suite,
    version: version,
    description: None,
    tests: tests,
  ))
}

// Conversion helper functions
fn convert_to_basic_test_case(
  test_case: UnifiedTestCase,
) -> Result(TestCase, Nil) {
  let expected = []
  Ok(TestCase(
    name: test_case.name,
    description: test_case.name,
    input: test_case.input,
    expected: expected,
    tags: test_case.meta.tags,
  ))
}

fn convert_to_error_test_case(
  test_case: UnifiedTestCase,
) -> Result(ErrorTestCase, Nil) {
  case is_some(test_case.expected_error) {
    True ->
      Ok(ErrorTestCase(
        name: test_case.name,
        description: test_case.name,
        input: test_case.input,
        expected_error: case test_case.expected_error {
          Some(err) -> err
          None -> False
        },
        error_message: case test_case.error_message {
          Some(msg) -> msg
          None -> ""
        },
        tags: test_case.meta.tags,
      ))
    False -> Error(Nil)
  }
}

/// Convert a NewUnifiedTestCase to a PrettyPrintTestCase if it has round-trip validation
fn convert_new_to_pretty_print_test_case(
  test_case: NewUnifiedTestCase,
) -> Result(PrettyPrintTestCase, Nil) {
  case test_case.validations.round_trip {
    Some(round_trip_spec) -> {
      Ok(PrettyPrintTestCase(
        name: test_case.name,
        property: round_trip_spec.property,
        input: test_case.input,
        expected_canonical: test_case.input, // For now, use input as expected canonical
        tags: test_case.meta.tags,
      ))
    }
    None -> Error(Nil)
  }
}
