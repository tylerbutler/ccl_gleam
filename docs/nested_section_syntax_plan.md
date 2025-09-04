# Nested Section Syntax - IMPLEMENTED ✅

## Overview

CCL's indented nested section syntax is **fully implemented** and working. Users can write hierarchical configurations using indentation, which are automatically parsed and converted to the existing dot-notation system for seamless access.

## Nested Section Syntax

Following the CCL specification, nested sections use indentation:

```ccl
beta =
  mode = sandbox
  capacity = 2

prod =
  capacity = 8
  database =
    host = prod-db.example.com
    port = 5432
```

## Target Output

Convert nested syntax to flat dot-notation entries compatible with existing `get_value()` functions:

```gleam
// Input (nested):
// beta =
//   mode = sandbox
//   capacity = 2

// Output (flat):
[
  Entry("beta.mode", "sandbox"),
  Entry("beta.capacity", "2")
]
```

## Current Implementation

### Core Functions (Already Available)
```gleam
// Parse CCL content including nested sections
pub fn parse(content: String) -> Result(List(Entry), ParseError)

// Convert entries to nested CCL structure with recursive parsing
pub fn make_objects(entries: List(Entry)) -> CCL

// Access nested values using dot notation
pub fn get_value(ccl: CCL, path: String) -> Result(String, String)
```

### How It Works
The implementation uses a **two-phase approach**:
1. **Parse phase**: Nested content becomes multiline values in entries
2. **Object construction**: `make_objects()` recursively parses nested CCL within values

## Implementation Algorithm

### Detection Phase
1. Parse CCL content into entries using existing parser
2. Identify "section entries" - entries where:
   - Value starts with newline
   - Value contains lines with "key = value" pattern
   - Lines follow proper indentation rules

### Flattening Phase
For each section entry:
1. Parse the multiline value as nested CCL
2. Extract key-value pairs from nested content
3. Prefix each key with the section name + "."
4. Create new Entry objects with dot-notation keys
5. Replace original section entry with flattened entries

### Example Transformation
```gleam
// Input entry:
Entry("beta", "\n  mode = sandbox\n  capacity = 2")

// Becomes:
[
  Entry("beta.mode", "sandbox"),
  Entry("beta.capacity", "2")
]
```

## Integration

### With Existing System
- **No changes** to core CCL data structures
- **Compatible** with existing `get_value(ccl, "beta.mode")` API
- **Additive** - can be used optionally in parsing pipeline

### Usage Pattern
```gleam
// Option 1: Direct parsing
let entries = parse_nested_sections(content)
let ccl = entries_to_ccl(entries)
let mode = get_value(ccl, "beta.mode")  // Works as expected

// Option 2: Post-processing
let entries = parse_ccl_string(content)  
let flattened = flatten_nested_sections(entries)
let ccl = entries_to_ccl(flattened)
```

## Benefits

1. **Hierarchical syntax** - More readable for complex configs
2. **Backward compatible** - Works with existing access patterns
3. **Optional** - Users can choose nested or dot-notation syntax
4. **Natural grouping** - Related settings visually grouped
5. **Standards compliant** - Follows CCL specification examples

## Edge Cases to Handle

1. **Mixed syntax** - Files with both nested and dot-notation entries
2. **Deep nesting** - Multiple levels of indentation
3. **Empty sections** - Sections with no nested content
4. **Malformed indentation** - Incorrect indentation levels
5. **Conflicting keys** - Same key defined in both styles

## Test Coverage ✅

The JSON test suite includes comprehensive nested section tests:

**Basic Tests:**
- `nested_key_value_pairs` - Basic nested structure parsing
- `deep_nested_structure` - Multi-level indentation 
- `nested_single_line` & `nested_multi_line` - Various formats

**Recursive Tests:**
- `recursive_nested_single` - Single nested field
- `recursive_nested_multiple` - Multiple nested fields  
- `deep_recursive_nesting` - Deep hierarchical structures

**Integration Tests:**
- `stress_test_complex_nesting` - Real-world complex scenarios
- Mixed nested and flat entries
- Proper whitespace handling
- Error cases and edge conditions

All tests **pass** - nested section syntax is production-ready!