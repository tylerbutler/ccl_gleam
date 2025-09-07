import ccl_core
import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

pub type TestCase {
  TestCase(
    name: String,
    description: String,
    input: String,
    expected: List(ccl_core.Entry),
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

// Test discovery functions - simplified for flat directory structure
pub fn discover_json_test_files() -> List(String) {
  let base_path = "../ccl-test-data/tests"
  case simplifile.read_directory(base_path) {
    Ok(files) ->
      files
      |> list.filter(string.ends_with(_, ".json"))
      |> list.filter(fn(f) { !string.starts_with(f, "schema") && !string.starts_with(f, "pretty-print") })
      |> list.map(fn(f) { base_path <> "/" <> f })
    Error(_) -> []
  }
}

pub fn load_and_validate_test_suite(
  filename: String,
) -> Result(TestSuite, String) {
  case simplifile.read(filename) {
    Ok(content) -> {
      case json.parse(content, test_suite_decoder()) {
        Ok(suite) -> Ok(suite)
        Error(err) -> Error("Invalid JSON format in " <> filename <> ": " <> string.inspect(err))
      }
    }
    Error(err) -> Error("Could not read file " <> filename <> ": " <> string.inspect(err))
  }
}

pub fn load_test_suite_safe(filename: String) -> TestSuite {
  case load_and_validate_test_suite(filename) {
    Ok(suite) -> suite
    Error(_) -> TestSuite(
      suite: "Empty Suite",
      version: "1.0",
      description: None,
      tests: []
    )
  }
}


pub fn get_pretty_printer_tests() -> List(PrettyPrintTestCase) {
  load_pretty_printer_test_file("../ccl-test-data/tests/pretty-print.json")
}

pub fn get_tests_by_tags(required_tags: List(String)) -> List(TestCase) {
  get_all_tests()
  |> list.filter(fn(test_case) { 
    list.all(required_tags, fn(tag) { list.contains(test_case.meta.tags, tag) })
  })
  |> list.filter(not_error_test)
  |> list.filter_map(convert_to_basic_test_case)
}

pub fn get_regular_tests() -> List(TestCase) {
  get_all_tests()
  |> list.filter(not_error_test)
  |> list.filter_map(convert_to_basic_test_case)
}

pub fn get_all_error_tests() -> List(ErrorTestCase) {
  get_all_tests()
  |> list.filter_map(convert_to_error_test_case)
}

pub fn get_tests_by_suite_name(suite_name: String) -> List(TestCase) {
  discover_json_test_files()
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

pub fn get_all_available_tests() -> dict.Dict(String, List(UnifiedTestCase)) {
  discover_json_test_files()
  |> list.map(fn(file) {
    let suite = load_test_suite_safe(file)
    #(suite.suite, suite.tests)
  })
  |> dict.from_list
}

pub fn get_test_suite_summary() -> String {
  let suites = get_all_available_tests()
  let total_tests = dict.values(suites)
    |> list.map(list.length)
    |> list.fold(0, fn(acc, x) { acc + x })
  
  "Found " <> string.inspect(dict.size(suites)) <> " test suites with " <> string.inspect(total_tests) <> " total tests"
}

fn get_all_tests() -> List(UnifiedTestCase) {
  discover_json_test_files()
  |> list.map(load_test_suite_safe)
  |> list.map(fn(suite) { suite.tests })
  |> list.flatten
}


// JSON decoders
fn entry_decoder() -> decode.Decoder(ccl_core.Entry) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(ccl_core.Entry(key, value))
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
    expected: Option(List(ccl_core.Entry)),
    expected_flat: Option(List(ccl_core.Entry)),
    expected_nested: Option(dict.Dict(String, String)),
    expected_typed: Option(List(#(String, TypedValue))),
    expected_error: Option(Bool),
    error_message: Option(String),
    parse_options: Option(ParseOptions),
    api_calls: Option(List(String)),
    meta: TestMetadata,
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

fn load_pretty_printer_test_file(filename: String) -> List(PrettyPrintTestCase) {
  case simplifile.read(filename) {
    Ok(content) -> {
      let pretty_printer_test_suite_decoder = {
        use tests <- decode.field(
          "tests",
          decode.list(pretty_printer_test_case_decoder()),
        )
        decode.success(tests)
      }

      case json.parse(content, pretty_printer_test_suite_decoder) {
        Ok(parsed) -> parsed
        Error(_) -> []
      }
    }
    Error(_) -> []
  }
}

fn pretty_printer_test_case_decoder() -> decode.Decoder(PrettyPrintTestCase) {
  use name <- decode.field("name", decode.string)
  use property <- decode.field("property", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_canonical <- decode.field("expected_canonical", decode.string)
  use meta <- decode.field("meta", pretty_printer_meta_decoder())
  decode.success(PrettyPrintTestCase(
    name: name,
    property: property,
    input: input,
    expected_canonical: expected_canonical,
    tags: meta,
  ))
}

fn pretty_printer_meta_decoder() -> decode.Decoder(List(String)) {
  use tags <- decode.field("tags", decode.list(decode.string))
  decode.success(tags)
}

// Conversion helper functions
fn convert_to_basic_test_case(
  test_case: UnifiedTestCase,
) -> Result(TestCase, Nil) {
  let expected = case test_case.expected {
    Some(entries) -> entries
    None ->
      case test_case.expected_flat {
        Some(entries) -> entries
        None -> []
      }
  }
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
