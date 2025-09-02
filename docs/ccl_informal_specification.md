# CCL (Categorical Configuration Language) Informal Specification

**Version:** 1.0  
**Date:** 2025-01-02  
**Status:** Living Document

This document consolidates the informal specification for CCL based on analysis of the blog post, reference implementations, and test suites.

## Sources

- **Primary:** [CCL Blog Post](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html) by Dmitrii Kovanikov (chshersh) 
- **Reference Implementation:** [OCaml CCL implementation](https://github.com/chshersh/ccl)
- **Test Suite:** Language-agnostic CCL test suite v1.0.0 (57 test cases)
- **This Implementation:** Gleam CCL implementation analysis

## Core Philosophy

**Source:** Blog Post

CCL is designed around the principle that "powerful software can emerge from simple, well-designed principles." The language demonstrates mathematical elegance through:

1. Minimal key-value pair foundation
2. Composition through Category Theory concepts (Semigroups, Monoids)
3. Fixed-point recursion for nested structures
4. Mathematical composition properties

## Basic Syntax

### Fundamental Unit
**Source:** Blog Post

The core unit is: `<key> = <value>`

### Key-Value Parsing Rules
**Sources:** Blog Post, Test Suite, Gleam Implementation

1. **Separator:** First `=` character separates key from value
2. **Key Trimming:** Leading and trailing whitespace (spaces, tabs) removed from keys
3. **Value Trimming:** Leading spaces removed, trailing whitespace preserved except for explicit trim
4. **Empty Values:** Values can be empty (key with no content after `=`)

### Line Structure
**Sources:** Test Suite, Gleam Implementation

- Each line can contain one key-value pair
- Lines without `=` are treated as continuation lines (indented content)
- Empty lines are preserved in multiline values
- Whitespace-only input is an error

## Advanced Syntax

### Multiline Values
**Sources:** Blog Post, Test Suite, Gleam Implementation

Values can span multiple lines using indentation-based continuation:

```ccl
description = First line
  Second line (continuation)
  Third line (continuation)
next_key = value
```

**Rules:**
1. Continuation lines must be indented beyond the base indentation level
2. Base indentation determined by first non-empty line with `=`
3. Blank lines within multiline values are preserved
4. Original indentation of continuation lines is maintained in the value

### Multi-line Key Support
**Sources:** Test Suite, Gleam Implementation

Keys can be split across lines using `=` on the following line:

```ccl
long key name
= value for the long key
```

**Rules:**
1. Key line cannot contain `=`
2. Next non-empty line must start with `=`
3. Value part follows normal value parsing rules

### Comments
**Sources:** Blog Post, Test Suite

Comments use special key conventions that can be filtered programmatically:

**Primary format:** `/= This is a comment`

**Alternative formats:**
- `#= Python-style comment`  
- `//= C-style comment`
- `/= Decorative comment =/`

**Implementation Pattern:**
- Comments are regular key-value entries
- Key is the comment marker (`/`, `#`, `//`, etc.)
- Value is the comment text
- Easy filtering: `filter(entry => entry.key !== "/")`

### Lists
**Sources:** Blog Post, Test Suite, Gleam Implementation

Lists use empty keys or indexed keys:

**Empty key format:**
```ccl
= item 1
= item 2  
= item 3
```

**Indexed format:**
```ccl
0 = item 1
1 = item 2
2 = item 3
```

### Nested Sections
**Sources:** Blog Post, Gleam Implementation

Nested configuration blocks using indentation:

```ccl
beta =
  mode = sandbox
  capacity = 2

prod =
  capacity = 8
```

**Rules:**
1. Empty value after `=` indicates nested section
2. Nested content must be indented
3. Recursive parsing applied to nested content
4. Fixed-point algorithm converts flat entries to nested structure

## Data Structure Representation

### Algebraic Data Types
**Source:** Blog Post

CCL can represent algebraic data types:

```ccl
empty =

single = 2025-06-25

range =
  0 = 2025-01-01
  1 = 2025-12-31
```

### Internal Structure
**Sources:** Gleam Implementation, Blog Post

CCL uses a recursive fixed-point data structure equivalent to OCaml's `type t = Fix of t Map.t`:

1. **Flat Parsing:** Input parsed to list of key-value entries
2. **Grouping:** Entries grouped by key, allowing multiple values
3. **Fixpoint Application:** Recursive structure built using mathematical fixed-point algorithm
4. **Terminal Values:** Leaf nodes stored using empty keys in the internal structure

## Parsing Behavior

### Edge Cases
**Sources:** Test Suite, Gleam Implementation

1. **Empty Input:** Truly empty input returns empty result
2. **Whitespace-only Input:** Error condition 
3. **Equals in Values:** Values can contain `=` characters
4. **Duplicate Keys:** Multiple entries with same key preserved in order
5. **Base Indentation:** Determined by first non-empty line containing key-value pair

### Error Conditions
**Sources:** Gleam Implementation, Test Suite

1. **Parse Errors:** Include line number and reason
2. **Continuation without Key:** Indented line without preceding key-value pair
3. **Invalid Structure:** Lines that don't conform to key-value or continuation patterns
4. **Whitespace-only Input:** Input containing only whitespace characters

### Whitespace Handling
**Sources:** Test Suite, Gleam Implementation

1. **Key Trimming:** All leading/trailing whitespace removed
2. **Value Leading Spaces:** Removed from start of values  
3. **Value Trailing Whitespace:** Preserved (spaces, tabs, etc.)
4. **Continuation Lines:** Right-stripped of trailing whitespace
5. **Indentation Preservation:** Original indentation maintained in multiline values

## Composition Properties

### Mathematical Foundation
**Source:** Blog Post

CCL configurations form mathematical structures:

- **Semigroup:** Configurations can be combined associatively
- **Monoid:** Empty configuration serves as identity element
- **Homomorphisms:** Structure-preserving transformations supported
- **Fixed-point Recursion:** Nested parsing uses mathematical fixed-point algorithms

### Composition Behavior
**Sources:** Test Suite, Blog Post

1. **Order Preservation:** When combining configurations, order is maintained
2. **Key Multiplication:** Same keys can appear multiple times
3. **Associativity:** `(a + b) + c = a + (b + c)`
4. **Identity:** Empty configuration + any config = that config

## Implementation Details

### Reference Behavior
**Sources:** OCaml Reference, Test Suite

The OCaml implementation serves as the specification reference for:

1. **Parsing Edge Cases:** How malformed input should be handled
2. **Whitespace Rules:** Exact trimming and preservation behavior  
3. **Error Messages:** Standard error formats and line number reporting
4. **Data Structure:** Internal representation and access patterns

### Extension Points
**Sources:** Blog Post, Test Suite

1. **Comment Syntax:** Flexible comment markers allow different styles
2. **Nested Formats:** Values can embed other configuration formats
3. **Type Inference:** Implementation-specific type interpretation
4. **Access APIs:** Different ways to query the parsed structure

## Conformance Requirements

### Core Requirements
**Sources:** All Sources

A CCL implementation MUST:

1. Parse basic `key = value` pairs correctly
2. Handle multiline values with indentation-based continuation
3. Preserve order of entries including duplicates
4. Implement proper key/value trimming rules
5. Support empty values and empty keys (for lists)
6. Handle nested sections with recursive parsing
7. Apply fixed-point algorithm for object construction

### Extension Requirements
**Sources:** Blog Post, Test Suite

A CCL implementation SHOULD:

1. Support comment filtering using special keys
2. Provide access APIs for different data types (strings, lists, objects)
3. Implement composition operations (merge, combine)
4. Handle error cases with line number reporting
5. Support query operations on nested structures

### Test Compliance
**Source:** Test Suite

Implementations should pass the standard test suite including:

- 57 regular test cases covering basic parsing
- 5 error test cases for malformed input
- 10 nested test cases for hierarchical structures
- Whitespace handling edge cases
- Comment processing verification
- Composition stability tests

## Future Extensions

### Planned Features
**Sources:** Blog Post, Implementation Analysis

1. **Typed Parsing:** Type-aware value interpretation
2. **Comment Layers:** Advanced comment filtering and processing
3. **Nested Section Syntax:** Enhanced hierarchical parsing
4. **Decorative Headers:** Visual organization features
5. **Format Embedding:** Support for embedding JSON, YAML, etc.

---

*This specification is derived from analysis of the CCL blog post, OCaml reference implementation, language-agnostic test suite, and the Gleam implementation. It represents the current understanding of CCL behavior and serves as a guide for implementation consistency.*