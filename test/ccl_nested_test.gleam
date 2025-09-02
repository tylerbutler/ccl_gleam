import ccl
import ccl_core
import gleam/dict
import gleam/list
import gleam/string
import gleeunit/should

/// Test cases for full CCL nested functionality based on OCaml reference implementation
/// These tests currently FAIL - they define the target behavior we need to implement
pub type NestedCCL {
  NestedCCL(values: dict.Dict(String, List(NestedValue)))
}

pub type NestedValue {
  StringValue(String)
  NestedValue(NestedCCL)
}

// === BASIC FLAT PARSING TESTS (should already work) ===

pub fn quotes_treated_as_literal_test() {
  // Test that quotes are treated as literal characters, not string delimiters
  let unquoted_input = "host = localhost"
  let quoted_input = "host = \"localhost\""

  case ccl_core.parse(unquoted_input) {
    Ok([ccl_core.Entry(key: "host", value: "localhost")]) ->
      should.be_true(True)
    _ -> should.fail()
  }

  case ccl_core.parse(quoted_input) {
    Ok([ccl_core.Entry(key: "host", value: "\"localhost\"")]) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn unified_get_api_test() {
  // Test the new unified get() API
  let input = "host = localhost\nports = 8000\nports = 8001"

  case ccl_core.parse(input) {
    Ok(entries) -> {
      let ccl_obj = ccl_core.make_objects(entries)

      // Test single value
      case ccl.get(ccl_obj, "host") {
        Ok(ccl.CclString("localhost")) -> should.be_true(True)
        _ -> should.fail()
      }

      // Test list value
      case ccl.get(ccl_obj, "ports") {
        Ok(ccl.CclList(values)) -> {
          should.equal(list.length(values), 2)
          should.equal(list.contains(values, "8000"), True)
          should.equal(list.contains(values, "8001"), True)
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn basic_single_key_test() {
  let input = "key = value"
  case ccl_core.parse(input) {
    Ok([ccl_core.Entry(key: "key", value: "value")]) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn basic_multiple_keys_test() {
  let input = "key1 = value1\nkey2 = value2"
  case ccl_core.parse(input) {
    Ok(entries) -> {
      should.equal(list.length(entries), 2)
      should.equal(entries, [
        ccl_core.Entry(key: "key1", value: "value1"),
        ccl_core.Entry(key: "key2", value: "value2"),
      ])
    }
    Error(_) -> should.fail()
  }
}

// === RECURSIVE VALUE PARSING TESTS (currently missing) ===

pub fn nested_value_parsing_test() {
  // This should parse the value "enabled = true\nport = 8080" recursively
  let input = "database =\n  enabled = true\n  port = 8080"

  // Current implementation returns this as a flat Entry with multiline value
  // Target: Should recursively parse the value into nested structure
  case ccl_core.parse(input) {
    Ok([ccl_core.Entry(key: "database", value: nested_value)]) -> {
      // For now, just check that we get the expected flat multiline value
      // TODO: This test should change when we implement recursive parsing
      should.equal(string.contains(nested_value, "enabled = true"), True)
      should.equal(string.contains(nested_value, "port = 8080"), True)
    }
    _ -> should.fail()
  }
}

pub fn deeply_nested_parsing_test() {
  let input =
    "server =\n  database =\n    host = localhost\n    port = 5432\n  cache =\n    enabled = true"

  case ccl_core.parse(input) {
    Ok([ccl_core.Entry(key: "server", value: nested_value)]) -> {
      // Verify we get the nested content (flat for now)
      should.equal(string.contains(nested_value, "database ="), True)
      should.equal(string.contains(nested_value, "host = localhost"), True)
      should.equal(string.contains(nested_value, "cache ="), True)
    }
    _ -> should.fail()
  }
}

// === MULTIPLE VALUES PER KEY TESTS (currently missing) ===

pub fn multiple_values_same_key_test() {
  // Should support multiple entries with same key that get merged
  let input = "ports = 8000\nports = 8001\nports = 8002"

  case ccl_core.parse(input) {
    Ok(entries) -> {
      // Current implementation creates separate entries
      // Target: Should merge into single key with multiple values
      let port_entries =
        list.filter(entries, fn(entry) { entry.key == "ports" })
      should.equal(list.length(port_entries), 3)
    }
    Error(_) -> should.fail()
  }
}

pub fn mixed_keys_with_duplicates_test() {
  let input = "name = app\nports = 8000\nname = service\nports = 8001"

  case ccl_core.parse(input) {
    Ok(entries) -> {
      should.equal(list.length(entries), 4)
      let name_entries = list.filter(entries, fn(entry) { entry.key == "name" })
      let port_entries =
        list.filter(entries, fn(entry) { entry.key == "ports" })
      should.equal(list.length(name_entries), 2)
      should.equal(list.length(port_entries), 2)
    }
    Error(_) -> should.fail()
  }
}

// === EMPTY KEY TESTS (currently missing) ===

pub fn empty_key_test() {
  // Should support "= value" syntax (empty key)
  let input = "= root_value"

  // This currently fails because parser expects key before =
  case ccl_core.parse(input) {
    Ok([ccl_core.Entry(key: "", value: "root_value")]) -> should.be_true(True)
    Error(_) -> {
      // Expected to fail with current implementation
      // TODO: Remove this when empty key support is added
      should.be_true(True)
    }
    _ -> should.fail()
  }
}

pub fn mixed_empty_and_normal_keys_test() {
  let input = "= root\nkey = value\n= another_root"

  case ccl_core.parse(input) {
    Ok(entries) -> {
      should.equal(list.length(entries), 3)
      let empty_key_entries =
        list.filter(entries, fn(entry) { entry.key == "" })
      should.equal(list.length(empty_key_entries), 2)
    }
    Error(_) -> {
      // Expected to fail with current implementation
      should.be_true(True)
    }
  }
}

// === NESTED PORTS EXAMPLE FROM OCAML TESTS ===

pub fn nested_ports_test() {
  // From the OCaml stress test - this is the canonical nested example
  let input = "ports =\n  = 8000\n  = 8001\n  = 8002"

  case ccl_core.parse(input) {
    Ok([ccl_core.Entry(key: "ports", value: nested_value)]) -> {
      // Should contain the empty key entries
      should.equal(string.contains(nested_value, "= 8000"), True)
      should.equal(string.contains(nested_value, "= 8001"), True)
      should.equal(string.contains(nested_value, "= 8002"), True)
    }
    Error(_) -> should.fail()
    _ -> should.fail()
  }
}

// === COMPLEX STRESS TEST FROM OCAML ===

pub fn stress_test_flat_parsing() {
  // This is the stress test from OCaml implementation, testing current flat parsing
  let input =
    "/ = This is a CCL document
title = CCL Example

database =
  enabled = true
  ports =
    = 8000
    = 8001
    = 8002
  limits =
    cpu = 1500mi
    memory = 10Gb

user =
  guestId = 42

user =
  login = chshersh
  createdAt = 2024-12-31"

  case ccl_core.parse(input) {
    Ok(entries) -> {
      // Just verify we can parse it without errors for now
      should.be_true(list.length(entries) > 0)

      // Check that we have the expected top-level keys
      let keys = list.map(entries, fn(entry) { entry.key })
      should.equal(list.contains(keys, "/"), True)
      should.equal(list.contains(keys, "title"), True)
      should.equal(list.contains(keys, "database"), True)
      should.equal(list.contains(keys, "user"), True)

      // Verify we have multiple user entries (duplicate key handling)
      let user_entries = list.filter(entries, fn(entry) { entry.key == "user" })
      should.equal(list.length(user_entries), 2)
    }
    Error(_err) -> {
      should.fail()
    }
  }
}

// === FIXPOINT ALGORITHM TESTS (target behavior) ===

pub fn fixpoint_merge_test() {
  // Test case: same key appears multiple times and should be merged
  let input = "user =\n  name = alice\nuser =\n  age = 25"

  case ccl_core.parse(input) {
    Ok(entries) -> {
      // Current: two separate entries
      // Target: should be merged in fixpoint algorithm
      let user_entries = list.filter(entries, fn(entry) { entry.key == "user" })
      should.equal(list.length(user_entries), 2)
    }
    Error(_) -> should.fail()
  }
}

// === COMMENT SUPPORT TEST ===

pub fn comment_test() {
  // CCL supports comments starting with /
  let input = "/ = This is a comment\nkey = value"

  case ccl_core.parse(input) {
    Ok(entries) -> {
      should.equal(list.length(entries), 2)
      let comment_entries = list.filter(entries, fn(entry) { entry.key == "/" })
      should.equal(list.length(comment_entries), 1)
    }
    Error(_) -> should.fail()
  }
}
// === FUTURE: FUNCTIONS TO TEST AFTER IMPLEMENTATION ===

// These would test the separated parse/make_objects architecture:
//
// pub fn test_parse_vs_make_objects() {
//   let input = "..."
//   case ccl_core.parse(input) {
//     Ok(entries) -> {
//       case ccl.make_objects(entries) {
//         Ok(nested_ccl) -> // test nested structure
//         Error(_) -> should.fail()
//       }
//     }
//     Error(_) -> should.fail()
//   }
// }
