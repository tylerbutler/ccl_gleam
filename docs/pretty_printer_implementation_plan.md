# CCL Pretty-Printer Implementation Plan

## Overview

This document outlines the implementation plan for a CCL pretty-printer that enables round-trip testing and homomorphism property verification for the CCL parser.

## Goals

1. **Round-trip Testing**: Enable `parse → pretty-print → parse` verification
2. **Homomorphism Verification**: Ensure structure-preserving transformations
3. **Canonical Formatting**: Provide consistent CCL output format
4. **Developer Tools**: Support config file normalization and formatting

## Design Requirements

### Core Functionality

- **Input**: `CCL` nested structure or `List(Entry)` flat entries
- **Output**: Canonical CCL text representation
- **Invertibility**: `parse(pretty_print(ccl)) == ccl` (up to normalization)
- **Consistency**: Same logical structure always produces same text output

### Formatting Rules

Based on existing CCL test cases and parsing behavior:

#### Whitespace Normalization
- **Keys**: Trim all leading/trailing whitespace 
- **Values**: Trim leading spaces, preserve trailing tabs (as per `tab_preservation_in_values` test)
- **Around equals**: Single space before and after `=`
- **Line endings**: Use `\n` (normalize CRLF → LF)

#### Indentation
- **Nested structures**: 2 spaces per level
- **Continuation lines**: Preserve relative indentation within multiline values
- **Empty lines**: Single blank line between major sections (optional feature)

#### Key-Value Formatting
```ccl
key = value
nested_key =
  sub_key = sub_value
  another_sub = another_value
```

#### Special Cases
- **Empty keys (lists)**: `= value` format
- **Comments**: `/ = comment text` (preserve existing comment markers)
- **Empty values**: `key =` (no trailing space)
- **Multiline values**: Preserve exact indentation patterns

## Implementation Architecture

### Core Functions

```gleam
// Main public API
pub fn pretty_print(ccl: CCL) -> String
pub fn pretty_print_entries(entries: List(Entry)) -> String

// Configuration options
pub type PrettyPrintOptions {
  PrettyPrintOptions(
    indent_size: Int,           // Default: 2
    preserve_empty_lines: Bool, // Default: False
    sort_keys: Bool,            // Default: False (preserve order)
    comment_spacing: Bool,      // Default: True (add spaces around comments)
  )
}

pub fn pretty_print_with_options(ccl: CCL, options: PrettyPrintOptions) -> String

// Internal helpers
fn format_entry(entry: Entry, indent_level: Int) -> String
fn format_multiline_value(value: String, indent_level: Int) -> String
fn normalize_whitespace(text: String) -> String
```

### Algorithm Design

#### Entry-Based Pretty Printing (Phase 1)
```gleam
pub fn pretty_print_entries(entries: List(Entry)) -> String {
  entries
  |> list.map(format_entry(_, 0))
  |> string.join("\n")
}

fn format_entry(entry: Entry, indent_level: Int) -> String {
  let Entry(key, value) = entry
  let indent = string.repeat(" ", indent_level * 2)
  
  case is_multiline(value) {
    True -> format_multiline_entry(key, value, indent_level)
    False -> indent <> key <> " = " <> value
  }
}
```

#### CCL Structure Pretty Printing (Phase 2)
```gleam
pub fn pretty_print(ccl: CCL) -> String {
  format_ccl_recursive(ccl, 0)
}

fn format_ccl_recursive(ccl: CCL, indent_level: Int) -> String {
  let CCL(map) = ccl
  
  dict.to_list(map)
  |> list.map(fn(entry) {
    let #(key, sub_ccl) = entry
    format_ccl_entry(key, sub_ccl, indent_level)
  })
  |> string.join("\n")
}
```

## Implementation Phases

### Phase 1: Basic Entry Pretty-Printing ✅ Minimum Viable Product
- [x] `pretty_print_entries(List(Entry)) -> String`
- [x] Basic key-value formatting
- [x] Multiline value handling
- [x] Whitespace normalization
- [x] Round-trip tests with existing test suite

### Phase 2: CCL Structure Pretty-Printing
- [ ] `pretty_print(CCL) -> String`
- [ ] Recursive nested structure formatting
- [ ] Empty key handling (lists)
- [ ] Structure preservation verification

### Phase 3: Advanced Formatting Options
- [ ] Configurable indentation
- [ ] Comment preservation and formatting
- [ ] Optional key sorting
- [ ] Section spacing options

### Phase 4: Round-Trip Test Integration
- [ ] Add round-trip tests to algebraic test suite
- [ ] Property-based round-trip testing
- [ ] Cross-validation with OCaml reference implementation

## Test Strategy

### Round-Trip Tests
```json
{
  "name": "round_trip_basic",
  "property": "round_trip",
  "input": "key = value\nnested =\n  sub = val",
  "expected_canonical": "key = value\nnested =\n  sub = val",
  "tags": ["round-trip", "formatting"]
}
```

### Edge Cases to Test
- Empty configurations
- Unicode content
- Mixed indentation (tabs/spaces)
- Comment preservation
- Deeply nested structures
- List-style empty key structures
- Multiline values with blank lines

## Integration Points

### With Existing Codebase
- Add to `ccl_core` package as `pretty_print.gleam`
- Extend test suite with round-trip tests
- Integrate with algebraic property tests

### Future Enhancements
- CLI formatting tool (`ccl fmt config.ccl`)
- Editor integration (format-on-save)
- Config migration tools
- Diff-friendly formatting options

## Implementation Priority

**High Priority**:
1. Basic entry pretty-printing for round-trip testing
2. Integration with test suite
3. Whitespace normalization consistency

**Medium Priority**:
1. CCL structure pretty-printing
2. Advanced formatting options
3. Performance optimization

**Low Priority**:
1. CLI tools
2. Editor integrations
3. Complex formatting preferences

## Success Criteria

1. **✅ All existing tests pass** after pretty-print → parse
2. **✅ Deterministic output** - same input always produces same output
3. **✅ Preserves semantics** - logical structure unchanged
4. **✅ Handles edge cases** - unicode, comments, empty values, nested structures
5. **✅ Performance** - reasonable speed for typical config files (< 1MB)

---

*This plan supports CCL's algebraic properties by enabling homomorphism testing and ensuring mathematical consistency between parsing and formatting operations.*