import ccl_core
import ccl_types.{Entry}
import gleam/list
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn empty_ccl_test() {
  let ccl = ccl_core.empty_ccl()
  ccl_core.get_keys(ccl, "") |> should.equal([])
}

// Essential smoke tests - comprehensive testing via JSON suites in ccl_test_loader
pub fn parse_simple_test() {
  ccl_core.parse("key = value") |> should.be_ok()
}

pub fn parse_error_test() {
  ccl_core.parse("invalid line without equals") |> should.be_error()  
}

// === NOTE: Comprehensive JSON test suites ===
// All JSON-driven tests are now executed by ccl_test_loader.
// This package focuses on ccl_core-specific unit tests only.
// Run comprehensive tests with: cd packages/ccl_test_loader && gleam test
