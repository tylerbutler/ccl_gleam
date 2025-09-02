import gleeunit
import gleeunit/should
import gleam/list
import gleam/string
import ccl_core
import ccl

pub fn main() {
  gleeunit.main()
}

pub fn node_type_test() {
  let entries = [
    ccl_core.Entry("single", "value"),
    ccl_core.Entry("list", "item1"),
    ccl_core.Entry("list", "item2"),
    ccl_core.Entry("obj.key", "nested_value")
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
    ccl_core.Entry("obj.key", "nested_value")
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
    ccl_core.Entry("list", "item2")
  ]
  let ccl_obj = ccl_core.make_objects(entries)
  
  ccl.get_smart_value(ccl_obj, "single") |> should.be_ok() |> should.equal("value")
  
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
    ccl_core.Entry("comment", "Custom comment key")
  ]
  
  // Test filtering single comment style
  let filtered_single = ccl.filter_keys(entries, ["/"])
  let single_keys = list.map(filtered_single, fn(entry) { entry.key })
  single_keys |> should.equal(["config", "setting", "#", "//", "data", "comment"])
  
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
    ccl_core.Entry("debug", "true")
  ]
  
  // Filter out comments and build CCL object
  let filtered = ccl.filter_keys(entries, ["/", "#"])
  let ccl_obj = ccl_core.make_objects(filtered)
  
  // Test that regular values work
  ccl.get_smart_value(ccl_obj, "server") |> should.be_ok() |> should.equal("localhost")
  ccl.get_smart_value(ccl_obj, "port") |> should.be_ok() |> should.equal("8080")
  ccl.get_smart_value(ccl_obj, "debug") |> should.be_ok() |> should.equal("true")
  
  // Test that comment keys are not accessible
  ccl.get_smart_value(ccl_obj, "/") |> should.be_error()
  ccl.get_smart_value(ccl_obj, "#") |> should.be_error()
}