import gleam/dict
import gleam/string
import gleeunit/should
import render/object
import test_types.{NodeList, NodeObject, NodeString}

// --- to_string ---

pub fn to_string_single_string_field_test() {
  let obj = dict.from_list([#("name", NodeString("alice"))])
  let result = object.to_string(obj)
  // Should be JSON format with indentation
  let assert True = string.contains(result, "\"name\": \"alice\"")
  let assert True = string.starts_with(result, "{")
  let assert True = string.ends_with(result, "}")
}

pub fn to_string_no_trailing_newline_test() {
  let obj = dict.from_list([#("key", NodeString("val"))])
  let result = object.to_string(obj)
  should.be_false(string.ends_with(result, "\n"))
}

pub fn to_string_nested_object_test() {
  let inner = dict.from_list([#("b", NodeString("2"))])
  let obj = dict.from_list([#("a", NodeObject(inner))])
  let result = object.to_string(obj)
  // Should contain nested braces
  let assert True = string.contains(result, "\"a\": {")
  let assert True = string.contains(result, "\"b\": \"2\"")
}

pub fn to_string_list_field_test() {
  let obj = dict.from_list([#("items", NodeList(["x", "y"]))])
  let result = object.to_string(obj)
  let assert True = string.contains(result, "\"items\": [\"x\", \"y\"]")
}

pub fn to_string_whitespace_in_value_visualized_test() {
  let obj = dict.from_list([#("key", NodeString("hello world"))])
  let result = object.to_string(obj)
  // Spaces in values should be visualized as middle-dot
  let assert True = string.contains(result, "hello·world")
}

pub fn to_string_whitespace_in_list_visualized_test() {
  let obj = dict.from_list([#("items", NodeList(["a b"]))])
  let result = object.to_string(obj)
  let assert True = string.contains(result, "a·b")
}
