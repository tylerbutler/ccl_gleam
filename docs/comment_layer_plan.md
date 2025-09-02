# Comment Layer Plan for CCL

## Overview

Add a simple optional comment filtering layer to CCL using key-based exclusion. Comments are treated as regular key-value pairs that can be filtered out using a single, flexible function.

## Comment Syntax

Following the CCL specification, comments use special keys:

- **Primary format**: `/= This is a comment`
- **Alternative formats**: 
  - `#= Python-style comment`
  - `//= C-style comment`
  - `comment = Any custom key`

## Implementation

### Single Filter Function
```gleam
// One function, always takes a list of keys to exclude
pub fn filter_keys(entries: List(Entry), exclude_keys: List(String)) -> List(Entry) {
  list.filter(entries, fn(entry) { !list.contains(exclude_keys, entry.key) })
}
```

### Usage Examples
```gleam
let entries = parse_ccl_string(content)

// Single comment style
let no_comments = filter_keys(entries, ["/"])

// Multiple comment styles  
let no_comments = filter_keys(entries, ["/", "#", "//"])

// Any keys you want to exclude
let filtered = filter_keys(entries, ["debug", "temp", "comment"])

// Then convert to CCL as usual
let ccl = entries_to_ccl(no_comments)
```

## Design Principles

1. **Simple**: One function does everything
2. **Flexible**: User chooses their own comment syntax
3. **Consistent**: Always requires an array of keys
4. **Optional**: Works as a filter layer on top of existing parsing
5. **Non-breaking**: Doesn't change existing CCL functionality

## Integration

- Add `filter_keys` function to `ccl.gleam`
- Works with existing `Entry(key: String, value: String)` structure
- Fits into parsing pipeline: `parse -> filter -> convert to CCL`
- No changes needed to core CCL parsing or data structures

## Benefits

- User controls comment syntax completely
- Can filter any keys, not just comments
- Simple API that's hard to misuse
- Minimal code footprint
- Follows CCL's flexibility principle