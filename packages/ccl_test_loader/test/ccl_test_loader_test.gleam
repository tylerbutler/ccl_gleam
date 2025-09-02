import gleeunit
import gleeunit/should
import gleam/json
import ccl_core
import ccl_test_loader

pub fn main() {
  gleeunit.main()
}

pub fn ccl_to_json_simple_test() {
  let entries = [ccl_core.Entry("key", "value")]
  let ccl = ccl_core.make_objects(entries)
  
  let json_result = ccl_test_loader.ccl_to_json(ccl)
  json.to_string(json_result) |> should.equal("{\"key\":\"value\"}")
}

pub fn json_to_ccl_simple_test() {
  let json_str = "{\"key\":\"value\"}"
  let result = ccl_test_loader.json_string_to_ccl(json_str)
  
  result |> should.be_ok()
  let ccl = case result {
    Ok(ccl) -> ccl
    Error(_) -> ccl_core.empty_ccl()
  }
  
  ccl_core.get_value(ccl, "key") |> should.be_ok() |> should.equal("value")
}

pub fn roundtrip_test() {
  let entries = [
    ccl_core.Entry("name", "test"),
    ccl_core.Entry("count", "42")
  ]
  let original_ccl = ccl_core.make_objects(entries)
  
  let json_str = ccl_test_loader.ccl_to_json_string(original_ccl)
  let restored_result = ccl_test_loader.json_string_to_ccl(json_str)
  
  restored_result |> should.be_ok()
  let restored_ccl = case restored_result {
    Ok(ccl) -> ccl
    Error(_) -> ccl_core.empty_ccl()
  }
  
  ccl_core.get_value(restored_ccl, "name") |> should.be_ok() |> should.equal("test")
  ccl_core.get_value(restored_ccl, "count") |> should.be_ok() |> should.equal("42")
}