/// Load JSON test files from ccl-test-data/generated_tests/
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/string
import simplifile
import test_runner/types.{
  type Conflicts, type Expected, type ExpectedNode, type Predicate,
  type TestCase, type TestSuite, Conflicts, ExpectedBool, ExpectedBoolean,
  ExpectedCountOnly, ExpectedEntries, ExpectedError, ExpectedFloat, ExpectedInt,
  ExpectedList, ExpectedObject, ExpectedValue, NodeList, NodeObject, NodeString,
  Predicate, TestCase, TestEntry, TestSuite,
}

/// Load a test suite from a JSON file
pub fn load_test_file(path: String) -> Result(TestSuite, String) {
  case simplifile.read(path) {
    Ok(content) -> parse_test_suite(content)
    Error(e) -> Error("Failed to read file: " <> string.inspect(e))
  }
}

/// Parse JSON content into a TestSuite
pub fn parse_test_suite(content: String) -> Result(TestSuite, String) {
  case json.parse(content, test_suite_decoder()) {
    Ok(suite) -> Ok(suite)
    Error(errors) -> Error("Failed to parse JSON: " <> string.inspect(errors))
  }
}

/// Decoder for the test suite
fn test_suite_decoder() -> decode.Decoder(TestSuite) {
  use tests <- decode.field("tests", decode.list(test_case_decoder()))
  decode.success(TestSuite(tests: tests))
}

/// Decoder for a single test case
fn test_case_decoder() -> decode.Decoder(TestCase) {
  use name <- decode.field("name", decode.string)
  use source_test <- decode.field("source_test", decode.string)
  use validation <- decode.field("validation", decode.string)
  use functions <- decode.field("functions", decode.list(decode.string))
  use inputs <- decode.field("inputs", decode.list(decode.string))
  // JSON uses American spelling "behaviors"; map to Gleam convention "behaviours"
  use behaviours <- decode.field("behaviors", decode.list(decode.string))
  use variants <- decode.field("variants", decode.list(decode.string))
  use features <- decode.field("features", decode.list(decode.string))
  use expected <- decode.field("expected", expected_decoder())
  use path <- decode.optional_field(
    "path",
    None,
    decode.optional(decode.list(decode.string)),
  )
  use args <- decode.optional_field(
    "args",
    None,
    decode.optional(decode.list(decode.string)),
  )
  use conflicts <- decode.optional_field(
    "conflicts",
    Conflicts(behaviours: []),
    conflicts_decoder(),
  )
  use predicate <- decode.optional_field(
    "predicate",
    None,
    decode.optional(predicate_decoder()),
  )

  decode.success(TestCase(
    name: name,
    source_test: source_test,
    validation: validation,
    functions: functions,
    inputs: inputs,
    behaviours: behaviours,
    variants: variants,
    features: features,
    expected: expected,
    path: path,
    args: args,
    conflicts: conflicts,
    predicate: predicate,
  ))
}

/// Decoder for the predicate field: `{field, op, value}`.
fn predicate_decoder() -> decode.Decoder(Predicate) {
  use field <- decode.field("field", decode.string)
  use op <- decode.field("op", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(Predicate(field: field, op: op, value: value))
}

/// Decoder for the conflicts field
fn conflicts_decoder() -> decode.Decoder(Conflicts) {
  use behaviours <- decode.optional_field(
    "behaviors",
    [],
    decode.list(decode.string),
  )
  decode.success(Conflicts(behaviours: behaviours))
}

/// Decoder for expected results (polymorphic)
fn expected_decoder() -> decode.Decoder(Expected) {
  // Try each expected format - use one_of for alternatives
  // count_only must be last since it's the most general (matches any expected with just count)
  decode.one_of(entries_expected_decoder(), [
    value_string_expected_decoder(),
    object_expected_decoder(),
    list_expected_decoder(),
    int_expected_decoder(),
    float_expected_decoder(),
    bool_expected_decoder(),
    error_expected_decoder(),
    boolean_expected_decoder(),
    count_only_expected_decoder(),
  ])
}

fn entries_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use entries <- decode.field("entries", decode.list(test_entry_decoder()))
  decode.success(ExpectedEntries(count: count, entries: entries))
}

fn test_entry_decoder() -> decode.Decoder(types.TestEntry) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(TestEntry(key: key, value: value))
}

fn value_string_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use value <- decode.field("value", decode.string)
  decode.success(ExpectedValue(count: count, value: value))
}

fn object_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use object <- decode.field("object", expected_node_dict_decoder())
  decode.success(ExpectedObject(count: count, object: object))
}

fn expected_node_dict_decoder() -> decode.Decoder(Dict(String, ExpectedNode)) {
  decode.dict(decode.string, expected_node_decoder())
}

fn expected_node_decoder() -> decode.Decoder(ExpectedNode) {
  decode.recursive(fn() {
    decode.one_of(
      // Try string first
      {
        use s <- decode.then(decode.string)
        decode.success(NodeString(s))
      },
      [
        // Try list of strings
        {
          use l <- decode.then(decode.list(decode.string))
          decode.success(NodeList(l))
        },
        // Try nested object (recursive)
        {
          use obj <- decode.then(decode.dict(
            decode.string,
            expected_node_decoder(),
          ))
          decode.success(NodeObject(obj))
        },
      ],
    )
  })
}

fn list_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use list <- decode.field("list", decode.list(decode.string))
  decode.success(ExpectedList(count: count, list: list))
}

fn int_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use value <- decode.field("value", decode.int)
  decode.success(ExpectedInt(count: count, value: value))
}

fn float_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use value <- decode.field("value", decode.float)
  decode.success(ExpectedFloat(count: count, value: value))
}

fn bool_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use value <- decode.field("value", decode.bool)
  decode.success(ExpectedBool(count: count, value: value))
}

fn error_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use error <- decode.field("error", decode.bool)
  decode.success(ExpectedError(count: count, error: error))
}

fn boolean_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  use boolean <- decode.field("boolean", decode.bool)
  decode.success(ExpectedBoolean(count: count, boolean: boolean))
}

/// Decoder for expected with only count field (used by filter and error tests)
fn count_only_expected_decoder() -> decode.Decoder(Expected) {
  use count <- decode.field("count", decode.int)
  decode.success(ExpectedCountOnly(count: count))
}

/// List all JSON test files in a directory
pub fn list_test_files(dir: String) -> Result(List(String), String) {
  case simplifile.read_directory(dir) {
    Ok(files) -> {
      let json_files =
        files
        |> list.filter(fn(f) { string.ends_with(f, ".json") })
        |> list.map(fn(f) { dir <> "/" <> f })
        |> list.sort(string.compare)
      Ok(json_files)
    }
    Error(e) -> Error("Failed to read directory: " <> string.inspect(e))
  }
}
