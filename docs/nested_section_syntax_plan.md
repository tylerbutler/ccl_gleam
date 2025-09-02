# Nested Section Syntax Parser Plan

## Overview

Add support for parsing CCL's indented nested section syntax and converting it to the existing dot-notation system. This allows users to write hierarchical configurations using indentation while maintaining compatibility with the current CCL implementation.

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

## API Design

### Core Parsing Function
```gleam
// Parse nested sections directly from CCL content
pub fn parse_nested_sections(content: String) -> Result(List(Entry), ParseError) {
  // 1. Parse content into entries using existing parser
  // 2. Identify entries with multiline values containing "key = value" patterns
  // 3. Extract nested key-value pairs from multiline values
  // 4. Convert to dot-notation entries
  // 5. Return flattened entry list
}
```

### Alternative Post-Processing Approach
```gleam
// Process already-parsed entries to flatten nested sections
pub fn flatten_nested_sections(entries: List(Entry)) -> List(Entry) {
  // Transform entries with multiline values into multiple flat entries
}
```

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

## Testing Requirements

- Parse single-level nested sections
- Parse multi-level nested sections  
- Handle mixed nested and flat entries
- Maintain whitespace in values correctly
- Generate appropriate error messages for malformed sections
- Integration with existing CCL access functions