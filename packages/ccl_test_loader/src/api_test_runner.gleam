import ccl_core
import ccl_types.{type CCL, type Entry}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import test_suite_types.{
  type NewUnifiedTestCase, type NodeType, Missing, SingleValue,
}

// === API TEST RESULT TYPES ===

pub type ApiTestResult {
  ParseTestResult(actual: List(Entry), expected: List(Entry), passed: Bool)
  MakeObjectsTestResult(actual: CCL, expected: CCL, passed: Bool)
  GetStringTestResult(actual: String, expected: String, passed: Bool)
  GetListTestResult(actual: List(String), expected: List(String), passed: Bool)
  NodeTypeTestResult(actual: NodeType, expected: NodeType, passed: Bool)
}

// === API TEST RUNNER ===

/// Run all API tests for a given test case
pub fn run_api_test(test_case: NewUnifiedTestCase) -> List(ApiTestResult) {
  let results = []

  // Test Level 1: parse
  let results = case test_case.validations.parse {
    Some(expected_entries) -> {
      case ccl_core.parse(test_case.input) {
        Ok(actual_entries) -> {
          let passed = entries_equal(actual_entries, expected_entries)
          [ParseTestResult(actual_entries, expected_entries, passed), ..results]
        }
        Error(_) -> [ParseTestResult([], expected_entries, False), ..results]
      }
    }
    None -> results
  }

  // Test Level 3: make_objects  
  let results = case test_case.validations.make_objects {
    Some(expected_ccl) -> {
      case ccl_core.parse(test_case.input) {
        Ok(entries) -> {
          let actual_ccl = ccl_core.make_objects(entries)
          let passed = ccl_equal(actual_ccl, expected_ccl)
          [MakeObjectsTestResult(actual_ccl, expected_ccl, passed), ..results]
        }
        Error(_) -> results
      }
    }
    None -> results
  }

  // Test Level 4: get_string
  let results = case test_case.validations.get_string {
    Some(expected_string) -> {
      case run_full_pipeline(test_case.input) {
        Ok(ccl_obj) -> {
          case
            get_smart_value_string(
              ccl_obj,
              extract_path_from_test_name(test_case.name),
            )
          {
            Ok(actual_string) -> {
              let passed = actual_string == expected_string
              [
                GetStringTestResult(actual_string, expected_string, passed),
                ..results
              ]
            }
            Error(_) -> [
              GetStringTestResult("", expected_string, False),
              ..results
            ]
          }
        }
        Error(_) -> results
      }
    }
    None -> results
  }

  // Test Level 4: get_list
  let results = case test_case.validations.get_list {
    Some(expected_list) -> {
      case run_full_pipeline(test_case.input) {
        Ok(ccl_obj) -> {
          case
            get_smart_value_list(
              ccl_obj,
              extract_path_from_test_name(test_case.name),
            )
          {
            Ok(actual_list) -> {
              let passed = actual_list == expected_list
              [GetListTestResult(actual_list, expected_list, passed), ..results]
            }
            Error(_) -> [GetListTestResult([], expected_list, False), ..results]
          }
        }
        Error(_) -> results
      }
    }
    None -> results
  }

  // Test Level 4: node_type
  let results = case test_case.validations.node_type {
    Some(expected_node_type) -> {
      case run_full_pipeline(test_case.input) {
        Ok(ccl_obj) -> {
          let actual_node_type =
            get_node_type(ccl_obj, extract_path_from_test_name(test_case.name))
          let passed = actual_node_type == expected_node_type
          [
            NodeTypeTestResult(actual_node_type, expected_node_type, passed),
            ..results
          ]
        }
        Error(_) -> [
          NodeTypeTestResult(Missing, expected_node_type, False),
          ..results
        ]
      }
    }
    None -> results
  }

  list.reverse(results)
}

// === HELPER FUNCTIONS ===

/// Run the complete CCL parsing pipeline
fn run_full_pipeline(input: String) -> Result(CCL, String) {
  case ccl_core.parse(input) {
    Ok(entries) -> {
      let ccl_obj = ccl_core.make_objects(entries)
      Ok(ccl_obj)
    }
    Error(_) -> Error("Parse error")
  }
}

/// Extract path from test name (simplified - assumes format like "test_path_to_value")
fn extract_path_from_test_name(name: String) -> String {
  // Simple implementation - extract everything after "test_"
  case string.split(name, "_") {
    ["test", ..rest] -> string.join(rest, ".")
    _ -> ""
  }
}

/// Compare two lists of entries for equality
fn entries_equal(actual: List(Entry), expected: List(Entry)) -> Bool {
  // Simple comparison - this could be enhanced with better semantic comparison
  actual == expected
}

/// Compare two CCL objects for equality
fn ccl_equal(actual: CCL, expected: CCL) -> Bool {
  // Simple comparison - this will need to be enhanced with proper CCL comparison
  actual == expected
}

/// Get a string value from CCL object (placeholder implementation)
fn get_smart_value_string(_ccl: CCL, path: String) -> Result(String, String) {
  // Placeholder - this needs to integrate with the actual CCL library API
  case path {
    "" -> Error("Empty path")
    _ -> Ok("placeholder_string")
  }
}

/// Get a list value from CCL object (placeholder implementation)  
fn get_smart_value_list(_ccl: CCL, path: String) -> Result(List(String), String) {
  // Placeholder - this needs to integrate with the actual CCL library API
  case path {
    "" -> Error("Empty path")
    _ -> Ok(["placeholder_item"])
  }
}

/// Get node type from CCL object (placeholder implementation)
fn get_node_type(_ccl: CCL, path: String) -> NodeType {
  // Placeholder - this needs to integrate with the actual CCL library API
  case path {
    "" -> Missing
    _ -> SingleValue
  }
}
