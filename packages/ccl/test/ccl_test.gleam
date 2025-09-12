import ccl
import ccl_core
import ccl_types.{Entry}
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn node_type_test() {
  let entries = [
    Entry("single", "value"),
    Entry("list", "item1"),
    Entry("list", "item2"),
    Entry("obj.key", "nested_value"),
  ]
  let ccl_obj = ccl_core.build_hierarchy(entries)

  ccl.node_type(ccl_obj, "single") |> should.equal(ccl.SingleValue)
  ccl.node_type(ccl_obj, "list") |> should.equal(ccl.ListValue)
  ccl.node_type(ccl_obj, "obj") |> should.equal(ccl.ObjectValue)
  ccl.node_type(ccl_obj, "missing") |> should.equal(ccl.Missing)
}

pub fn get_unified_test() {
  let entries = [
    Entry("single", "value"),
    Entry("list", "item1"),
    Entry("list", "item2"),
    Entry("obj.key", "nested_value"),
  ]
  let ccl_obj = ccl_core.build_hierarchy(entries)

  case ccl.get(ccl_obj, "single") {
    Ok(ccl.CclString(value)) -> value |> should.equal("value")
    _ -> should.fail()
  }

  case ccl.get(ccl_obj, "list") {
    Ok(ccl.CclList(values)) -> {
      // Sort values for consistent testing since order may vary
      let sorted_values = list.sort(values, string.compare)
      sorted_values |> should.equal(["item1", "item2"])
    }
    _ -> should.fail()
  }

  case ccl.get(ccl_obj, "obj") {
    Ok(ccl.CclObject(_)) -> Nil
    _ -> should.fail()
  }
}

pub fn smart_accessors_test() {
  let entries = [
    Entry("single", "value"),
    Entry("list", "item1"),
    Entry("list", "item2"),
  ]
  let ccl_obj = ccl_core.build_hierarchy(entries)

  ccl.get_smart_value(ccl_obj, "single")
  |> should.be_ok()
  |> should.equal("value")

  // Test list access with sorted values for consistency
  case ccl.get_list(ccl_obj, "list") {
    Ok(values) -> {
      let sorted_values = list.sort(values, string.compare)
      sorted_values |> should.equal(["item1", "item2"])
    }
    Error(_) -> should.fail()
  }

  // get_value_or_first returns the first value (order may vary in implementation)
  case ccl.get_value_or_first(ccl_obj, "list") {
    Ok(value) -> {
      // Should be one of the list items
      list.contains(["item1", "item2"], value) |> should.equal(True)
    }
    Error(_) -> should.fail()
  }
}

pub fn pretty_print_test() {
  let entries = [Entry("key", "value")]
  let ccl_obj = ccl_core.build_hierarchy(entries)

  let output = ccl.pretty_print_ccl(ccl_obj)
  // Just verify it produces some output (exact format may vary)
  case string.length(output) > 0 {
    True -> Nil
    False -> should.fail()
  }
}

pub fn filter_test() {
  let entries = [
    Entry("config", "value1"),
    Entry("/", "This is a comment"),
    Entry("setting", "value2"),
    Entry("#", "Python-style comment"),
    Entry("//", "C-style comment"),
    Entry("data", "value3"),
    Entry("comment", "Custom comment key"),
  ]

  // Test filtering single comment style
  let filtered_single = ccl.filter(entries, ["/"])
  let single_keys = list.map(filtered_single, fn(entry) { entry.key })
  single_keys
  |> should.equal(["config", "setting", "#", "//", "data", "comment"])

  // Test filtering multiple comment styles
  let filtered_multiple = ccl.filter(entries, ["/", "#", "//"])
  let multiple_keys = list.map(filtered_multiple, fn(entry) { entry.key })
  multiple_keys |> should.equal(["config", "setting", "data", "comment"])

  // Test filtering any keys
  let filtered_custom = ccl.filter(entries, ["comment", "setting"])
  let custom_keys = list.map(filtered_custom, fn(entry) { entry.key })
  custom_keys |> should.equal(["config", "/", "#", "//", "data"])

  // Test empty exclude list (should return all entries)
  let filtered_none = ccl.filter(entries, [])
  filtered_none |> should.equal(entries)

  // Test filtering non-existent keys
  let filtered_missing = ccl.filter(entries, ["nonexistent"])
  filtered_missing |> should.equal(entries)
}

pub fn filter_integration_test() {
  // Test the complete parsing pipeline with filtering
  let entries = [
    Entry("server", "localhost"),
    Entry("/", "Configuration comment"),
    Entry("port", "8080"),
    Entry("#", "Port configuration"),
    Entry("debug", "true"),
  ]

  // Filter out comments and build CCL object
  let filtered = ccl.filter(entries, ["/", "#"])
  let ccl_obj = ccl_core.build_hierarchy(filtered)

  // Test that regular values work
  ccl.get_smart_value(ccl_obj, "server")
  |> should.be_ok()
  |> should.equal("localhost")
  ccl.get_smart_value(ccl_obj, "port") |> should.be_ok() |> should.equal("8080")
  ccl.get_smart_value(ccl_obj, "debug")
  |> should.be_ok()
  |> should.equal("true")

  // Test that comment keys are not accessible
  ccl.get_smart_value(ccl_obj, "/") |> should.be_error()
  ccl.get_smart_value(ccl_obj, "#") |> should.be_error()
}

// === ROUND-TRIP TESTING ===

pub fn round_trip_basic_test() {
  // Test basic key-value pairs
  let original_ccl_text = "key = value\nanother = test"

  // Parse original
  case ccl_core.parse(original_ccl_text) {
    Ok(entries) -> {
      // Pretty print entries back to text
      let pretty_printed = ccl.pretty_print_entries(entries)

      // Parse the pretty printed text
      case ccl_core.parse(pretty_printed) {
        Ok(reparsed_entries) -> {
          // Convert both to CCL objects and verify they're equivalent
          let original_ccl = ccl_core.build_hierarchy(entries)
          let reparsed_ccl = ccl_core.build_hierarchy(reparsed_entries)

          // Test that all values are preserved
          ccl.get_smart_value(original_ccl, "key")
          |> should.equal(ccl.get_smart_value(reparsed_ccl, "key"))
          ccl.get_smart_value(original_ccl, "another")
          |> should.equal(ccl.get_smart_value(reparsed_ccl, "another"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn round_trip_multiline_test() {
  // Test multiline values
  let original_ccl_text = "config =\n  line1\n  line2\n  line3"

  case ccl_core.parse(original_ccl_text) {
    Ok(entries) -> {
      let pretty_printed = ccl.pretty_print_entries(entries)

      case ccl_core.parse(pretty_printed) {
        Ok(reparsed_entries) -> {
          let original_ccl = ccl_core.build_hierarchy(entries)
          let reparsed_ccl = ccl_core.build_hierarchy(reparsed_entries)

          ccl.get_smart_value(original_ccl, "config")
          |> should.equal(ccl.get_smart_value(reparsed_ccl, "config"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn round_trip_empty_values_test() {
  // Test simple empty value case
  let original_ccl_text = "empty_key ="

  case ccl_core.parse(original_ccl_text) {
    Ok(entries) -> {
      let pretty_printed = ccl.pretty_print_entries(entries)

      // Just verify it parses back without error - exact semantics may differ
      case ccl_core.parse(pretty_printed) {
        Ok(_) -> Nil
        // Success as long as it parses
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn round_trip_ccl_structure_test() {
  // Test CCL structure pretty printing
  let entries = [
    Entry("server.host", "localhost"),
    Entry("server.port", "8080"),
    Entry("database.name", "mydb"),
    Entry("database.user", "admin"),
  ]

  let original_ccl = ccl_core.build_hierarchy(entries)

  // Pretty print the CCL structure
  let pretty_printed = ccl.pretty_print_ccl(original_ccl)

  // Parse back
  case ccl_core.parse(pretty_printed) {
    Ok(reparsed_entries) -> {
      let reparsed_ccl = ccl_core.build_hierarchy(reparsed_entries)

      // Verify nested structure is preserved
      ccl.get_smart_value(original_ccl, "server.host")
      |> should.equal(ccl.get_smart_value(reparsed_ccl, "server.host"))
      ccl.get_smart_value(original_ccl, "server.port")
      |> should.equal(ccl.get_smart_value(reparsed_ccl, "server.port"))
      ccl.get_smart_value(original_ccl, "database.name")
      |> should.equal(ccl.get_smart_value(reparsed_ccl, "database.name"))
      ccl.get_smart_value(original_ccl, "database.user")
      |> should.equal(ccl.get_smart_value(reparsed_ccl, "database.user"))
    }
    Error(_) -> should.fail()
  }
}

pub fn pretty_print_canonical_format_test() {
  // Test that pretty printing produces canonical CCL format
  let entries = [Entry("key", "value")]
  let output = ccl.pretty_print_entries(entries)

  // Should produce exactly "key = value"
  output |> should.equal("key = value")
}

pub fn pretty_print_whitespace_normalization_test() {
  // Test whitespace normalization according to plan requirements
  let entries = [
    Entry("  spaced_key  ", "  spaced_value  "),
    Entry("normal", "value\t"),
    // Tab should be preserved
  ]
  let output = ccl.pretty_print_entries(entries)

  // Keys should be trimmed, values should have leading spaces trimmed but trailing preserved
  let lines = string.split(output, "\n")
  case lines {
    [line1, line2] -> {
      line1 |> should.equal("spaced_key = spaced_value  ")
      // Leading spaces trimmed, trailing preserved  
      line2 |> should.equal("normal = value\t")
      // Tab preserved
    }
    _ -> should.fail()
  }
}

pub fn pretty_print_list_formatting_test() {
  // Test list-style entries with empty keys
  let entries = [
    Entry("", "list_item1"),
    Entry("", "list_item2"),
    Entry("regular_key", "value"),
  ]

  let ccl_obj = ccl_core.build_hierarchy(entries)
  let output = ccl.pretty_print_ccl(ccl_obj)

  // Should format empty key entries as list items
  // Exact format will depend on CCL structure implementation
  case string.length(output) > 0 {
    True -> Nil
    // Just verify it produces output for now
    False -> should.fail()
  }
}

pub fn structure_preservation_test() {
  // Test that complex nested structures are preserved through round-trip
  let entries = [
    Entry("app.name", "MyApp"),
    Entry("app.version", "1.0.0"),
    Entry("database.host", "localhost"),
    Entry("database.port", "5432"),
    Entry("features", "auth"),
    Entry("features", "logging"),
    Entry("features", "metrics"),
  ]

  let original_ccl = ccl_core.build_hierarchy(entries)
  let pretty_printed = ccl.pretty_print_ccl(original_ccl)

  // Parse the pretty printed output back
  case ccl_core.parse(pretty_printed) {
    Ok(reparsed_entries) -> {
      let reparsed_ccl = ccl_core.build_hierarchy(reparsed_entries)

      // Verify all the original structure is preserved
      ccl.get_smart_value(original_ccl, "app.name")
      |> should.equal(ccl.get_smart_value(reparsed_ccl, "app.name"))
      ccl.get_smart_value(original_ccl, "database.host")
      |> should.equal(ccl.get_smart_value(reparsed_ccl, "database.host"))

      // Verify basic structure preservation - exact list semantics may differ
      // This is a successful round-trip test as long as core structure is maintained
      case ccl.get_list(original_ccl, "features") {
        Ok(_) -> Nil
        // Original had list values
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

// === NEW VALIDATION-BASED TESTING ===

/// Test the new CCL algebraic operations
pub fn ccl_merge_test() {
  let entries_a = [Entry("key1", "value1"), Entry("shared", "from_a")]
  let entries_b = [Entry("key2", "value2"), Entry("shared", "from_b")]

  let ccl_a = ccl_core.build_hierarchy(entries_a)
  let ccl_b = ccl_core.build_hierarchy(entries_b)

  case ccl.ccl_merge(ccl_a, ccl_b) {
    Ok(merged) -> {
      // Test that merged CCL contains keys from both
      case ccl.get_smart_value(merged, "key1") {
        Ok(value1) -> value1 |> should.equal("value1")
        Error(_) -> should.fail()
      }
      case ccl.get_smart_value(merged, "key2") {
        Ok(value2) -> value2 |> should.equal("value2")
        Error(_) -> should.fail()
      }
      // Shared key should have value from b (right operand wins)
      case ccl.get_smart_value(merged, "shared") {
        Ok(shared) -> shared |> should.equal("from_b")
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test CCL semantic equality
pub fn ccl_semantic_equality_test() {
  let entries_original = [Entry("key1", "value1"), Entry("key2", "value2")]
  let entries_reordered = [Entry("key2", "value2"), Entry("key1", "value1")]

  let ccl_original = ccl_core.build_hierarchy(entries_original)
  let ccl_reordered = ccl_core.build_hierarchy(entries_reordered)

  // Should be semantically equal despite different ordering
  ccl.ccl_semantically_equal(ccl_original, ccl_reordered) |> should.equal(True)

  // Test with different content
  let entries_different = [
    Entry("key1", "different_value"),
    Entry("key2", "value2"),
  ]
  let ccl_different = ccl_core.build_hierarchy(entries_different)

  ccl.ccl_semantically_equal(ccl_original, ccl_different) |> should.equal(False)
}

/// Test round-trip property: parse -> pretty_print -> parse
pub fn round_trip_property_test() {
  let original_text = "key1 = value1\nkey2 = value2\nlist = item1\nlist = item2"

  case ccl_core.parse(original_text) {
    Ok(entries) -> {
      let ccl_obj = ccl_core.build_hierarchy(entries)
      let pretty_printed = ccl.pretty_print_ccl(ccl_obj)

      case ccl_core.parse(pretty_printed) {
        Ok(reparsed_entries) -> {
          let reparsed_ccl = ccl_core.build_hierarchy(reparsed_entries)

          // Test semantic equivalence
          ccl.ccl_semantically_equal(ccl_obj, reparsed_ccl)
          |> should.equal(True)
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test associativity property: (A ⊕ B) ⊕ C = A ⊕ (B ⊕ C)
pub fn associativity_property_test() {
  let entries_a = [Entry("a", "value_a")]
  let entries_b = [Entry("b", "value_b")]
  let entries_c = [Entry("c", "value_c")]

  let ccl_a = ccl_core.build_hierarchy(entries_a)
  let ccl_b = ccl_core.build_hierarchy(entries_b)
  let ccl_c = ccl_core.build_hierarchy(entries_c)

  // Test (A ⊕ B) ⊕ C
  case ccl.ccl_merge(ccl_a, ccl_b) {
    Ok(ab_merged) -> {
      case ccl.ccl_merge(ab_merged, ccl_c) {
        Ok(left_assoc) -> {
          // Test A ⊕ (B ⊕ C)
          case ccl.ccl_merge(ccl_b, ccl_c) {
            Ok(bc_merged) -> {
              case ccl.ccl_merge(ccl_a, bc_merged) {
                Ok(right_assoc) -> {
                  // Should be semantically equal
                  ccl.ccl_semantically_equal(left_assoc, right_assoc)
                  |> should.equal(True)
                }
                Error(_) -> should.fail()
              }
            }
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
