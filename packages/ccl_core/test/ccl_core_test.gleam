import gleeunit
import gleeunit/should
import gleam/list
import gleam/string
import ccl_core

pub fn main() {
  gleeunit.main()
}

pub fn empty_ccl_test() {
  let ccl = ccl_core.empty_ccl()
  ccl_core.get_keys(ccl, "") |> should.equal([])
}

pub fn parse_simple_test() {
  let result = ccl_core.parse("key = value")
  result |> should.be_ok()
  
  let entries = case result {
    Ok(entries) -> entries
    Error(_) -> []
  }
  entries |> should.equal([ccl_core.Entry("key", "value")])
}

pub fn make_objects_simple_test() {
  let entries = [ccl_core.Entry("key", "value")]
  let ccl = ccl_core.make_objects(entries)
  
  ccl_core.get_value(ccl, "key") |> should.be_ok() |> should.equal("value")
}

pub fn get_nested_test() {
  let entries = [
    ccl_core.Entry("db.host", "localhost"),
    ccl_core.Entry("db.port", "5432")
  ]
  let ccl = ccl_core.make_objects(entries)
  
  ccl_core.get_value(ccl, "db.host") |> should.be_ok() |> should.equal("localhost")
  ccl_core.get_value(ccl, "db.port") |> should.be_ok() |> should.equal("5432")
  
  let nested_result = ccl_core.get_nested(ccl, "db")
  nested_result |> should.be_ok()
}

// Test some basic parsing functionality using hardcoded examples
// (Full JSON test suite integration should be done at the workspace level)

pub fn parse_multiline_test() {
  let input = "key1 = value1
key2 = value2"
  let result = ccl_core.parse(input)
  result |> should.be_ok()
  
  case result {
    Ok(entries) -> {
      list.length(entries) |> should.equal(2)
      let first = case list.first(entries) {
        Ok(entry) -> entry
        Error(_) -> ccl_core.Entry("", "")
      }
      first.key |> should.equal("key1")
      first.value |> should.equal("value1")
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_error_test() {
  let input = "invalid line without equals"
  let result = ccl_core.parse(input)
  result |> should.be_error()
}