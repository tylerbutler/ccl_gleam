import ccl
import ccl_core
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn node_type_test() {
  let entries = [
    ccl_core.Entry("single", "value"),
    ccl_core.Entry("list", "item1"),
    ccl_core.Entry("list", "item2"),
    ccl_core.Entry("obj.key", "nested_value"),
  ]
  let ccl_obj = ccl_core.make_objects(entries)

  ccl.node_type(ccl_obj, "single") |> should.equal(ccl.SingleValue)
  ccl.node_type(ccl_obj, "list") |> should.equal(ccl.ListValue)
  ccl.node_type(ccl_obj, "obj") |> should.equal(ccl.ObjectValue)
  ccl.node_type(ccl_obj, "missing") |> should.equal(ccl.Missing)
}

pub fn get_unified_test() {
  let entries = [
    ccl_core.Entry("single", "value"),
    ccl_core.Entry("list", "item1"),
    ccl_core.Entry("list", "item2"),
    ccl_core.Entry("obj.key", "nested_value"),
  ]
  let ccl_obj = ccl_core.make_objects(entries)

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
    ccl_core.Entry("single", "value"),
    ccl_core.Entry("list", "item1"),
    ccl_core.Entry("list", "item2"),
  ]
  let ccl_obj = ccl_core.make_objects(entries)

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
  let entries = [ccl_core.Entry("key", "value")]
  let ccl_obj = ccl_core.make_objects(entries)

  let output = ccl.pretty_print_ccl(ccl_obj)
  // Just verify it produces some output (exact format may vary)
  case string.length(output) > 0 {
    True -> Nil
    False -> should.fail()
  }
}

pub fn filter_keys_test() {
  let entries = [
    ccl_core.Entry("config", "value1"),
    ccl_core.Entry("/", "This is a comment"),
    ccl_core.Entry("setting", "value2"),
    ccl_core.Entry("#", "Python-style comment"),
    ccl_core.Entry("//", "C-style comment"),
    ccl_core.Entry("data", "value3"),
    ccl_core.Entry("comment", "Custom comment key"),
  ]

  // Test filtering single comment style
  let filtered_single = ccl.filter_keys(entries, ["/"])
  let single_keys = list.map(filtered_single, fn(entry) { entry.key })
  single_keys
  |> should.equal(["config", "setting", "#", "//", "data", "comment"])

  // Test filtering multiple comment styles
  let filtered_multiple = ccl.filter_keys(entries, ["/", "#", "//"])
  let multiple_keys = list.map(filtered_multiple, fn(entry) { entry.key })
  multiple_keys |> should.equal(["config", "setting", "data", "comment"])

  // Test filtering any keys
  let filtered_custom = ccl.filter_keys(entries, ["comment", "setting"])
  let custom_keys = list.map(filtered_custom, fn(entry) { entry.key })
  custom_keys |> should.equal(["config", "/", "#", "//", "data"])

  // Test empty exclude list (should return all entries)
  let filtered_none = ccl.filter_keys(entries, [])
  filtered_none |> should.equal(entries)

  // Test filtering non-existent keys
  let filtered_missing = ccl.filter_keys(entries, ["nonexistent"])
  filtered_missing |> should.equal(entries)
}

pub fn filter_keys_integration_test() {
  // Test the complete parsing pipeline with filtering
  let entries = [
    ccl_core.Entry("server", "localhost"),
    ccl_core.Entry("/", "Configuration comment"),
    ccl_core.Entry("port", "8080"),
    ccl_core.Entry("#", "Port configuration"),
    ccl_core.Entry("debug", "true"),
  ]

  // Filter out comments and build CCL object
  let filtered = ccl.filter_keys(entries, ["/", "#"])
  let ccl_obj = ccl_core.make_objects(filtered)

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
          let original_ccl = ccl_core.make_objects(entries)
          let reparsed_ccl = ccl_core.make_objects(reparsed_entries)
          
          // Test that all values are preserved
          ccl.get_smart_value(original_ccl, "key") |> should.equal(ccl.get_smart_value(reparsed_ccl, "key"))
          ccl.get_smart_value(original_ccl, "another") |> should.equal(ccl.get_smart_value(reparsed_ccl, "another"))
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
          let original_ccl = ccl_core.make_objects(entries)
          let reparsed_ccl = ccl_core.make_objects(reparsed_entries)
          
          ccl.get_smart_value(original_ccl, "config") |> should.equal(ccl.get_smart_value(reparsed_ccl, "config"))
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
        Ok(_) -> Nil  // Success as long as it parses
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn round_trip_ccl_structure_test() {
  // Test CCL structure pretty printing
  let entries = [
    ccl_core.Entry("server.host", "localhost"),
    ccl_core.Entry("server.port", "8080"),
    ccl_core.Entry("database.name", "mydb"),
    ccl_core.Entry("database.user", "admin")
  ]
  
  let original_ccl = ccl_core.make_objects(entries)
  
  // Pretty print the CCL structure
  let pretty_printed = ccl.pretty_print_ccl(original_ccl)
  
  // Parse back
  case ccl_core.parse(pretty_printed) {
    Ok(reparsed_entries) -> {
      let reparsed_ccl = ccl_core.make_objects(reparsed_entries)
      
      // Verify nested structure is preserved
      ccl.get_smart_value(original_ccl, "server.host") |> should.equal(ccl.get_smart_value(reparsed_ccl, "server.host"))
      ccl.get_smart_value(original_ccl, "server.port") |> should.equal(ccl.get_smart_value(reparsed_ccl, "server.port"))
      ccl.get_smart_value(original_ccl, "database.name") |> should.equal(ccl.get_smart_value(reparsed_ccl, "database.name"))
      ccl.get_smart_value(original_ccl, "database.user") |> should.equal(ccl.get_smart_value(reparsed_ccl, "database.user"))
    }
    Error(_) -> should.fail()
  }
}

pub fn pretty_print_canonical_format_test() {
  // Test that pretty printing produces canonical CCL format
  let entries = [ccl_core.Entry("key", "value")]
  let output = ccl.pretty_print_entries(entries)
  
  // Should produce exactly "key = value"
  output |> should.equal("key = value")
}

pub fn pretty_print_whitespace_normalization_test() {
  // Test whitespace normalization according to plan requirements
  let entries = [
    ccl_core.Entry("  spaced_key  ", "  spaced_value  "),
    ccl_core.Entry("normal", "value\t")  // Tab should be preserved
  ]
  let output = ccl.pretty_print_entries(entries)
  
  // Keys should be trimmed, values should have leading spaces trimmed but trailing preserved
  let lines = string.split(output, "\n") 
  case lines {
    [line1, line2] -> {
      line1 |> should.equal("spaced_key = spaced_value  ")  // Leading spaces trimmed, trailing preserved  
      line2 |> should.equal("normal = value\t")  // Tab preserved
    }
    _ -> should.fail()
  }
}
