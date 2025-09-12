import ccl_test_loader
import gleam/list
import gleam/option.{None}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test data for filtering tests
fn create_test_case(name: String, level: Int, tags: List(String)) -> ccl_test_loader.TestCase {
  ccl_test_loader.TestCase(
    name: name,
    input: "key = value",
    expected: [],
    meta: ccl_test_loader.TestMeta(tags: tags, level: level, conflicts: None),
  )
}

fn sample_tests() -> List(ccl_test_loader.TestCase) {
  [
    // Tests designed for the new feature-based filtering system
    create_test_case("basic parsing", 1, ["function:parse"]),
    create_test_case("comment handling", 2, ["feature:comments", "function:parse"]),  
    create_test_case("object construction", 3, ["function:make-objects"]),
    create_test_case("dotted keys", 3, ["feature:dotted-keys", "function:make-objects"]),
    create_test_case("typed string access", 4, ["function:get-string"]),
    create_test_case("typed int access", 4, ["function:get-int"]),
    create_test_case("proposed variant test", 1, ["function:parse", "variant:proposed-behavior"]),
    create_test_case("legacy variant test", 1, ["function:parse", "variant:legacy-unsupported"]),
  ]
}

// Level filtering tests
pub fn by_level_test() {
  let tests = sample_tests()
  
  let level_1 = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByLevel(1))
  should.equal(3, list.length(level_1))  // basic parsing + 2 variant tests
  
  let level_2 = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByLevel(2))
  should.equal(1, list.length(level_2))  // comment handling
  
  let level_3 = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByLevel(3))
  should.equal(2, list.length(level_3))  // object construction + dotted keys
  
  let level_4 = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByLevel(4))
  should.equal(2, list.length(level_4))  // typed string + typed int access
}

// Function tag filtering tests
pub fn by_function_test() {
  let tests = sample_tests()
  
  let parse_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFunction("parse"))
  should.equal(4, list.length(parse_tests))  // basic + comment + 2 variant tests
  
  let make_objects_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFunction("make-objects"))
  should.equal(2, list.length(make_objects_tests))  // object construction + dotted keys
  
  let get_string_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFunction("get-string"))
  should.equal(1, list.length(get_string_tests))  // typed string access
  
  let get_int_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFunction("get-int"))
  should.equal(1, list.length(get_int_tests))  // typed int access
}

// Feature tag filtering tests  
pub fn by_feature_test() {
  let tests = sample_tests()
  
  let comment_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFeature("comments"))
  should.equal(1, list.length(comment_tests))
  
  let dotted_key_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFeature("dotted-keys"))
  should.equal(1, list.length(dotted_key_tests))
}




// All filter test (should return all tests)
pub fn all_filter_test() {
  let tests = sample_tests()
  
  let all_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.All)
  should.equal(8, list.length(all_tests))
}

// Variant filtering tests
pub fn variant_filter_test() {
  let tests = sample_tests()
  
  let proposed_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByVariant("proposed-behavior"))
  should.equal(1, list.length(proposed_tests))  // Only the proposed variant test
  
  let reference_tests = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByVariant("reference-compliant"))
  should.equal(0, list.length(reference_tests))  // No reference-compliant tests in sample
}

// Test edge cases
pub fn edge_cases_test() {
  let tests = sample_tests()
  
  // Non-existent level
  let no_level = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByLevel(99))
  should.equal(0, list.length(no_level))
  
  // Non-existent function
  let no_function = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFunction("nonexistent"))
  should.equal(0, list.length(no_function))
  
  // Non-existent feature
  let no_feature = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByFeature("nonexistent"))
  should.equal(0, list.length(no_feature))
  
  // Non-existent variant
  let no_variant = ccl_test_loader.filter_tests(tests, ccl_test_loader.ByVariant("nonexistent"))
  should.equal(0, list.length(no_variant))
}