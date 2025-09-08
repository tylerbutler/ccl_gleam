import ccl_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn entry_creation_test() {
  let entry = ccl_types.Entry("key", "value")
  entry.key |> should.equal("key")
  entry.value |> should.equal("value")
}

pub fn parse_error_creation_test() {
  let error = ccl_types.ParseError(1, "Test error")
  error.line |> should.equal(1)
  error.reason |> should.equal("Test error")
}