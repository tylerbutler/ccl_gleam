import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleeunit/should

/// Target data structures and test cases based on OCaml reference implementation
/// These define the API we want to achieve

// === TARGET DATA STRUCTURES ===

/// The core recursive CCL type (equivalent to OCaml's `type t = Fix of t Map.t`)
pub type CCL {
  CCL(map: dict.Dict(String, CCL))
}

/// Value entry type for intermediate processing (equivalent to OCaml's value_entry)
pub type ValueEntry {
  StringValue(String)
  NestedCCL(dict.Dict(String, List(ValueEntry)))
}

/// Key-value pair type (same as OCaml)
pub type KeyVal {
  KeyVal(key: String, value: String)
}

// === TARGET API FUNCTIONS (to be implemented) ===

/// Parse string into flat key-value pairs (core parsing only)
// pub fn parse_core(input: String) -> Result(List(KeyVal), ParseError)

/// Parse value string recursively into key-value pairs 
// pub fn parse_value(input: String) -> Result(List(KeyVal), ParseError)

/// Convert flat key-value pairs into nested CCL structure (fixpoint algorithm)
// pub fn make_objects(kvs: List(KeyVal)) -> CCL

/// Pretty print CCL structure
// pub fn pretty_print(ccl: CCL) -> String

// === HELPER FUNCTIONS FOR TESTING ===

pub fn empty_ccl() -> CCL {
  CCL(dict.new())
}

pub fn single_key_val(key: String, value: String) -> CCL {
  let inner_dict = dict.from_list([#(value, empty_ccl())])
  let inner_ccl = CCL(inner_dict)
  let outer_dict = dict.from_list([#(key, inner_ccl)])
  CCL(outer_dict)
}

pub fn nested_ccl(key: String, nested: List(CCL)) -> CCL {
  let merged = list.fold(nested, empty_ccl(), merge_ccl)
  CCL(dict.from_list([#(key, merged)]))
}

pub fn merge_ccl(ccl1: CCL, ccl2: CCL) -> CCL {
  case ccl1, ccl2 {
    CCL(map1), CCL(map2) -> {
      let merged_map = dict.fold(map2, map1, fn(acc, key, value2) {
        case dict.get(acc, key) {
          Ok(value1) -> dict.insert(acc, key, merge_ccl(value1, value2))
          Error(_) -> dict.insert(acc, key, value2)
        }
      })
      CCL(merged_map)
    }
  }
}

pub fn ccl_from_list(ccls: List(CCL)) -> CCL {
  list.fold(ccls, empty_ccl(), merge_ccl)
}

// === TARGET TEST CASES ===

pub fn test_target_empty() {
  let kvs = []
  let expected = empty_ccl()
  // This would test: make_objects(kvs) == expected
  should.be_true(True) // Placeholder until implemented
}

pub fn test_target_single_key_val() {
  let kvs = [KeyVal("key", "value")]
  let expected = single_key_val("key", "value")
  // This would test: make_objects(kvs) == expected
  should.be_true(True) // Placeholder until implemented
}

pub fn test_target_multiple_same_keys() {
  // Test the key insight: multiple entries with same key should merge
  let kvs = [
    KeyVal("ports", "8000"),
    KeyVal("ports", "8001"), 
    KeyVal("ports", "8002")
  ]
  
  // Expected: single "ports" key containing all three values
  let expected = nested_ccl("ports", [
    single_key_val("", "8000"),
    single_key_val("", "8001"),
    single_key_val("", "8002")
  ])
  
  should.be_true(True) // Placeholder until implemented
}

pub fn test_target_nested_structure() {
  // Test nested value parsing + object creation
  let kvs = [
    KeyVal("database", "enabled = true\nport = 5432")
  ]
  
  // Expected: database key containing nested enabled and port
  let expected = nested_ccl("database", [
    ccl_from_list([
      single_key_val("enabled", "true"),
      single_key_val("port", "5432")
    ])
  ])
  
  should.be_true(True) // Placeholder until implemented
}

pub fn test_target_stress_case() {
  // The full stress test from OCaml implementation
  let kvs = [
    KeyVal("/", "This is a CCL document"),
    KeyVal("title", "CCL Example"),
    KeyVal("database", "enabled = true\nports =\n  = 8000\n  = 8001\n  = 8002\nlimits =\n  cpu = 1500mi\n  memory = 10Gb"),
    KeyVal("user", "guestId = 42"),
    KeyVal("user", "login = chshersh\ncreatedAt = 2024-12-31")
  ]
  
  // Expected nested structure (simplified representation)
  let expected = ccl_from_list([
    single_key_val("/", "This is a CCL document"),
    single_key_val("title", "CCL Example"),
    nested_ccl("database", [
      ccl_from_list([
        single_key_val("enabled", "true"),
        nested_ccl("ports", [
          single_key_val("", "8000"),
          single_key_val("", "8001"), 
          single_key_val("", "8002")
        ]),
        nested_ccl("limits", [
          ccl_from_list([
            single_key_val("cpu", "1500mi"),
            single_key_val("memory", "10Gb")
          ])
        ])
      ])
    ]),
    nested_ccl("user", [
      ccl_from_list([
        single_key_val("guestId", "42"),
        single_key_val("login", "chshersh"), 
        single_key_val("createdAt", "2024-12-31")
      ])
    ])
  ])
  
  should.be_true(True) // Placeholder until implemented
}

// === PARSING BEHAVIOR TESTS ===

pub fn test_parse_value_behavior() {
  // Test that parse_value treats indented content as key-value pairs
  let input = "  enabled = true\n  port = 5432"
  
  // Expected: parse_value should return [KeyVal("enabled", "true"), KeyVal("port", "5432")]
  // Note: parse_value handles indentation differently than parse_core
  
  should.be_true(True) // Placeholder until implemented
}

pub fn test_empty_key_parsing() {
  // Test parsing of "= value" (empty key)
  let input = "= 8000\n= 8001"
  
  // Expected: [KeyVal("", "8000"), KeyVal("", "8001")]
  
  should.be_true(True) // Placeholder until implemented
}

pub fn test_mixed_indentation_levels() {
  // Test that different indentation levels are handled correctly
  let input = "key1 = value1\n  nested1 = value2\n    deep = value3\n  nested2 = value4"
  
  // The parse_value function should determine the base indentation level
  // and treat everything at that level or greater as part of the value
  
  should.be_true(True) // Placeholder until implemented
}

// === FIXPOINT ALGORITHM TESTS ===

pub fn test_fixpoint_convergence() {
  // Test that the fixpoint algorithm converges
  // Some values might need multiple rounds of parsing to fully resolve
  
  let kvs = [
    KeyVal("outer", "inner = middle = deep = value")
  ]
  
  // After round 1: outer -> [KeyVal("inner", "middle = deep = value")]
  // After round 2: outer -> inner -> [KeyVal("middle", "deep = value")]  
  // After round 3: outer -> inner -> middle -> [KeyVal("deep", "value")]
  // After round 4: no change (converged)
  
  should.be_true(True) // Placeholder until implemented
}

// === UTILITY FUNCTIONS FOR FUTURE IMPLEMENTATION ===

// Helper to verify CCL structure equality (would be needed for real tests)
pub fn ccl_equal(ccl1: CCL, ccl2: CCL) -> Bool {
  case ccl1, ccl2 {
    CCL(map1), CCL(map2) -> {
      dict.size(map1) == dict.size(map2) && 
      dict.fold(map1, True, fn(acc, key, value1) {
        case dict.get(map2, key) {
          Ok(value2) -> acc && ccl_equal(value1, value2)
          Error(_) -> False
        }
      })
    }
  }
}

// Helper to pretty print CCL for debugging
pub fn debug_ccl(ccl: CCL) -> String {
  case ccl {
    CCL(map) -> {
      let entries = dict.to_list(map)
      case entries {
        [] -> "{}"
        _ -> {
          let formatted = list.map(entries, fn(pair) {
            let #(key, value) = pair
            "\"" <> key <> "\": " <> debug_ccl(value)
          })
          "{" <> list.fold(formatted, "", fn(acc, item) {
            case acc {
              "" -> item
              _ -> acc <> ", " <> item
            }
          }) <> "}"
        }
      }
    }
  }
}