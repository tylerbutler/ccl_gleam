# CCL Test Analysis and Implementation Plan

## Current Status ✅

**What Already Works:**
- ✅ Basic key-value parsing (`key = value`)
- ✅ Multi-line values with continuation lines
- ✅ Empty keys (`= value`)
- ✅ Whitespace handling and trimming
- ✅ Comments (`/ = comment`)
- ✅ Multiple key-value pairs
- ✅ Unicode support
- ✅ All 53 core CCL parsing tests pass

**Current API:**
```gleam
pub fn parse(input: String) -> Result(List(Entry), ParseError)

pub type Entry {
  Entry(key: String, value: String)
}
```

## Missing Functionality ❌

Based on comparison with OCaml reference implementation and spec:

### 1. Recursive Value Parsing
**Current:** Values are parsed as flat strings
```gleam
// Input: "database =\n  host = localhost\n  port = 5432"
// Current output: [Entry("database", "host = localhost\nport = 5432")]
```

**Target:** Values should be recursively parsed
```gleam
// Should parse nested values and create structured data
```

### 2. Fixpoint Algorithm for Object Construction
**Current:** No object construction - just flat key-value pairs

**Target:** Build nested objects using fixpoint algorithm
```gleam
// Multiple entries with same key should merge
// Values should be recursively parsed until no more parsing possible
```

### 3. Proper Nested Data Structure
**Current:** Flat `Entry` list

**Target:** Recursive CCL structure like OCaml's `type t = Fix of t Map.t`

## Implementation Plan 

### Phase 1: Separate Parse and Object Construction
```gleam
// Keep current core parser
pub fn parse(input: String) -> Result(List(Entry), ParseError)

// Add value parser  
pub fn parse_value(input: String) -> Result(List(Entry), ParseError)

// Add object constructor
pub fn make_objects(entries: List(Entry)) -> CCL
```

### Phase 2: Recursive Value Parsing
- Implement `parse_value` that handles indented content
- Detect when values contain key-value pairs
- Parse them recursively

### Phase 3: Fixpoint Object Construction 
- Implement the recursive `Fix` data structure
- Create fixpoint algorithm that keeps parsing until convergence
- Handle merging of duplicate keys

### Phase 4: Integration
- Update examples to use new API
- Ensure backward compatibility
- Add comprehensive tests

## Test Cases Added

### Basic Tests (in `ccl_nested_test.gleam`)
- [x] Recursive value parsing tests
- [x] Multiple values per key tests  
- [x] Empty key support tests
- [x] Complex stress test cases
- [x] Fixpoint algorithm tests

### Target Behavior Tests (in `ccl_target_behavior_test.gleam`)
- [x] Target data structures defined
- [x] API specifications
- [x] Helper functions for testing
- [x] Expected behavior examples

## Key Insights from OCaml Implementation

1. **Two-stage parsing:** First parse to key-value pairs, then build objects
2. **Recursive values:** Values can contain more CCL that needs parsing
3. **Fixpoint convergence:** Keep parsing until no more changes occur
4. **Merge strategy:** Multiple entries with same key get merged recursively
5. **Empty key semantics:** `= value` creates entry with empty string key

## Next Steps

1. ✅ Create comprehensive test cases (DONE)
2. 🔄 Implement `parse_value` function 
3. 🔄 Implement recursive CCL data structure
4. 🔄 Implement fixpoint algorithm
5. 🔄 Update examples and documentation