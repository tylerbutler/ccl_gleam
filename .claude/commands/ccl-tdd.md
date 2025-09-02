# CCL Test-Driven Development

Run CCL-specific tests with focus on parsing and type safety.

First, create a test for expected CCL behavior:
```
// In test/ccl_test.gleam
import gleam/should
import ccl

pub fn test_parse_simple_config() {
  let input = "key = value"
  ccl.parse(input)
  |> should.be_ok()
}
```

Then run tests and implement:
```
gleam test --module ccl_test
```

Arguments: $ARGUMENTS

This workflow:
- Follows TDD principles for CCL features
- Tests parsing edge cases first
- Validates type safety and error handling
- Ensures fixpoint algorithm correctness