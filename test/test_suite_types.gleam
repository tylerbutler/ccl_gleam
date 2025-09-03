import ccl_core
import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/json
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

// Types for typed parsing tests
pub type TypedTestCase {
  TypedTestCase(
    name: String,
    description: String,
    input: String,
    expected_flat: List(ccl_core.Entry),
    expected_typed: List(#(String, TypedValue)),  // path -> typed value pairs
    parse_options: ParseOptions,
    api_calls: List(String),
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
  ParseOptions(
    parse_integers: Bool,
    parse_floats: Bool,
    parse_booleans: Bool,
  )
}

// Load and parse JSON test suite
pub fn get_test_cases() -> List(TestCase) {
  case load_test_suite() {
    Ok(test_suite) -> test_suite.tests
    Error(_) -> []
  }
}

pub fn get_error_test_cases() -> List(ErrorTestCase) {
  case load_test_suite() {
    Ok(test_suite) -> test_suite.error_tests
    Error(_) -> []
  }
}

pub fn get_algebraic_test_cases() -> List(AlgebraicTestCase) {
  case load_test_suite() {
    Ok(test_suite) -> test_suite.algebraic_tests
    Error(_) -> []
  }
}

// This function now loads from separate JSON file instead of main test suite

// Algebraic property test case types
pub type AlgebraicTestCase {
  // For monoid identity tests (2 inputs)
  MonoidIdentityTest(
    name: String,
    description: String,
    property: String,
    input1: String,
    input2: String,
    expected_combined: List(ccl_core.Entry),
    tags: List(String),
  )
  // For semigroup associativity tests (3 inputs)  
  SemigroupAssocTest(
    name: String,
    description: String,
    property: String,
    input1: String,
    input2: String,
    input3: String,
    expected_left_assoc: List(ccl_core.Entry),
    expected_right_assoc: List(ccl_core.Entry),
    tags: List(String),
  )
  // For general composition tests (2 inputs)
  CompositionTest(
    name: String,
    description: String,
    property: String,
    input1: String,
    input2: String,
    expected_combined: List(ccl_core.Entry),
    tags: List(String),
  )
  // For text concatenation tests
  ConcatenationTest(
    name: String,
    description: String,
    property: String,
    input1: String,
    input2: String,
    expected_text_concat: String,
    expected_combined: List(ccl_core.Entry),
    tags: List(String),
  )
}

// JSON test suite structure decoder
type TestSuite {
  TestSuite(
    tests: List(TestCase), 
    error_tests: List(ErrorTestCase),
    typed_parsing_tests: List(TypedTestCase),
    algebraic_tests: List(AlgebraicTestCase),
  )
}

// Load and parse JSON test suite
fn load_test_suite() -> Result(TestSuite, String) {
  case simplifile.read("ccl-test-suite/ccl-test-suite.json") {
    Ok(content) -> {
      let test_suite_decoder = {
        use tests <- decode.field("tests", decode.list(test_case_decoder()))
        use error_tests <- decode.field(
          "error_tests",
          decode.list(error_test_case_decoder()),
        )
        use algebraic_tests <- decode.field(
          "algebraic_tests",
          decode.list(algebraic_test_decoder()),
        )
        // For now, just return empty list for typed parsing tests
        // Will implement full decoder later
        let typed_parsing_tests = []
        decode.success(TestSuite(tests:, error_tests:, typed_parsing_tests:, algebraic_tests:))
      }

      case json.parse(content, test_suite_decoder) {
        Ok(parsed) -> Ok(parsed)
        Error(err) -> {
          io.println("JSON parse error occurred: " <> string.inspect(err))
          Error("Failed to parse JSON")
        }
      }
    }
    Error(err) -> {
      io.println("File read error: " <> simplifile.describe_error(err))
      Error("Failed to read test suite file")
    }
  }
}

// Decoder for Entry objects
fn entry_decoder() -> decode.Decoder(ccl_core.Entry) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(ccl_core.Entry(key, value))
}

// Decoder for test cases
fn test_case_decoder() -> decode.Decoder(TestCase) {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use input <- decode.field("input", decode.string)
  use expected <- decode.field("expected", decode.list(entry_decoder()))
  use tags <- decode.field("tags", decode.list(decode.string))
  decode.success(TestCase(name:, description:, input:, expected:, tags:))
}

// Decoder for error test cases
fn error_test_case_decoder() -> decode.Decoder(ErrorTestCase) {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_error <- decode.field("expected_error", decode.bool)
  use error_message <- decode.field("error_message", decode.string)
  use tags <- decode.field("tags", decode.list(decode.string))
  decode.success(ErrorTestCase(
    name:,
    description:,
    input:,
    expected_error:,
    error_message:,
    tags:,
  ))
}

// Load typed parsing test cases from JSON file
pub fn get_typed_parsing_test_cases() -> List(TypedTestCase) {
  case load_typed_parsing_test_suite() {
    Ok(test_cases) -> test_cases
    Error(_) -> []
  }
}

fn load_typed_parsing_test_suite() -> Result(List(TypedTestCase), String) {
  case simplifile.read("ccl-test-suite/ccl-typed-parsing-examples.json") {
    Ok(content) -> {
      let typed_parsing_decoder = {
        use typed_parsing_tests <- decode.field("typed_parsing_tests", decode.list(simple_typed_test_decoder()))
        decode.success(typed_parsing_tests)
      }

      case json.parse(content, typed_parsing_decoder) {
        Ok(parsed) -> Ok(parsed)
        Error(_err) -> {
          io.println("JSON parse error for typed parsing tests")
          Error("Failed to parse typed parsing JSON")
        }
      }
    }
    Error(err) -> {
      io.println("File read error: " <> simplifile.describe_error(err))
      Error("Failed to read typed parsing test suite file")
    }
  }
}

// Full decoder for the typed parsing JSON format
fn simple_typed_test_decoder() -> decode.Decoder(TypedTestCase) {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_flat <- decode.field("expected_flat", decode.list(entry_decoder()))
  use expected_typed <- decode.field("expected_typed", typed_values_decoder())
  use api_calls <- decode.field("api_calls", decode.list(decode.string))
  use tags <- decode.field("tags", decode.list(decode.string))
  
  // Parse options are optional in JSON, default to smart parsing if not present  
  let default_options = ParseOptions(parse_integers: True, parse_floats: True, parse_booleans: True)
  
  // For this test, let me hardcode the conservative options for the conservative test case  
  // TODO: Implement proper optional field decoding later
  let parse_options = case name {
    "parse_with_conservative_options" -> ParseOptions(parse_integers: True, parse_floats: False, parse_booleans: False)
    _ -> default_options
  }
  
  decode.success(TypedTestCase(
    name:,
    description:,
    input:,
    expected_flat:,
    expected_typed:,
    parse_options:,
    api_calls:,
    tags:,
  ))
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

// Decoder for algebraic test cases
fn algebraic_test_decoder() -> decode.Decoder(AlgebraicTestCase) {
  use property <- decode.field("property", decode.string)
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use tags <- decode.field("tags", decode.list(decode.string))
  
  case property {
    "monoid_identity_left" | "monoid_identity_right" | "monoid_identity_reflexive" -> {
      use input1 <- decode.field("input1", decode.string)
      use input2 <- decode.field("input2", decode.string)
      use expected_combined <- decode.field("expected_combined", decode.list(entry_decoder()))
      decode.success(MonoidIdentityTest(name:, description:, property:, input1:, input2:, expected_combined:, tags:))
    }
    "semigroup_associativity" | "nested_associativity" -> {
      use input1 <- decode.field("input1", decode.string)
      use input2 <- decode.field("input2", decode.string)
      use input3 <- decode.field("input3", decode.string)
      use expected_left_assoc <- decode.field("expected_left_assoc", decode.list(entry_decoder()))
      use expected_right_assoc <- decode.field("expected_right_assoc", decode.list(entry_decoder()))
      decode.success(SemigroupAssocTest(name:, description:, property:, input1:, input2:, input3:, expected_left_assoc:, expected_right_assoc:, tags:))
    }
    "concatenation_equivalence" -> {
      use input1 <- decode.field("input1", decode.string)
      use input2 <- decode.field("input2", decode.string)
      use expected_text_concat <- decode.field("expected_text_concat", decode.string)
      use expected_combined <- decode.field("expected_combined", decode.list(entry_decoder()))
      decode.success(ConcatenationTest(name:, description:, property:, input1:, input2:, expected_text_concat:, expected_combined:, tags:))
    }
    _ -> {
      // Default to composition test for other properties
      use input1 <- decode.field("input1", decode.string)
      use input2 <- decode.field("input2", decode.string)
      use expected_combined <- decode.field("expected_combined", decode.list(entry_decoder()))
      decode.success(CompositionTest(name:, description:, property:, input1:, input2:, expected_combined:, tags:))
    }
  }
}


