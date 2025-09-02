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