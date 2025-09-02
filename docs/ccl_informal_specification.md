# CCL (Categorical Configuration Language) Informal Specification

**Version:** 1.2.0  
**Date:** 2025-01-02  
**Status:** Living Document

This document consolidates the informal specification for CCL based on analysis of the blog post, reference implementations, and test suites.

**Version 1.2.0 Changes:**
- Resolved visual vs logical indentation issue with consistency rules
- Added mixed indentation detection and warning guidelines
- Introduced strict parsing mode concept
- Clarified that tabs count as 1 indentation unit

**Version 1.1.0 Changes:**
- Added explicit core parsing algorithm section
- Clarified whitespace and indentation handling throughout
- Major reorganization for better user experience
- Distinguished core vs. non-core features
- Added quick start guide and implementation checklist

## Table of Contents

- [Sources](#sources)
- [Quick Start](#quick-start)
- [Core Philosophy](#core-philosophy)
- [Syntax Reference](#syntax-reference)
- [Core Parsing Algorithm](#-core-parsing-algorithm)
- [Data Structure Representation](#data-structure-representation)
- [Error Handling](#error-handling)
- [Edge Cases](#edge-cases)
- [Outstanding Design Issues](#outstanding-design-issues)
- [Implementation Checklist](#implementation-checklist)
- [Implementation Details](#implementation-details)
- [Mathematical Foundation](#mathematical-foundation)
- [Conformance Requirements](#conformance-requirements)
- [Future Extensions](#future-extensions)
- [Quick Reference Card](#quick-reference-card)

## Sources

- **Primary:** [CCL Blog Post](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html) by Dmitrii Kovanikov (chshersh) 
- **Reference Implementation:** [OCaml CCL implementation](https://github.com/chshersh/ccl)
- **Test Suite:** Language-agnostic CCL test suite v1.0.0 (57 test cases)
- **This Implementation:** Gleam CCL implementation analysis

## Quick Start

Here's a simple CCL configuration to get you started:

```ccl
name = My Application
version = 1.0.0
debug = true

database =
  host = localhost
  port = 5432
  name = myapp_db

features =
  = authentication
  = logging
  = metrics

/= This is a comment
description = A sample application
  with multiline description
  that preserves indentation
```

**Parsing Result:**
- `name` → `"My Application"`
- `version` → `"1.0.0"`
- `debug` → `"true"`
- `database` → nested object with `host`, `port`, `name`
- `features` → list with 3 items
- `description` → multiline string preserving formatting

**Key Points:**
- Use `key = value` for basic entries
- Empty values after `=` create nested sections
- Empty keys (`= item`) create list items
- Lines starting with `/=` are comments
- Indentation continues values or creates nesting

## Core Philosophy

**Source:** Blog Post

CCL is designed around the principle that "powerful software can emerge from simple, well-designed principles." The language demonstrates mathematical elegance through:

1. Minimal key-value pair foundation
2. Composition through Category Theory concepts (Semigroups, Monoids)
3. Fixed-point recursion for nested structures
4. Mathematical composition properties

## Syntax Reference

### Fundamental Unit
**Source:** Blog Post

The core unit is: `<key> = <value>`

### Basic Key-Value Pairs
**Sources:** Blog Post, Test Suite, Gleam Implementation

**Format:** `key = value`

**Rules:**
1. **Separator:** First `=` character separates key from value
2. **Key Processing:** Keys are trimmed of all whitespace (see Whitespace Handling Rules)
3. **Value Processing:** Leading spaces removed, trailing whitespace preserved (see Whitespace Handling Rules)
4. **Empty Values:** Values can be empty (key with no content after `=`)

**Line Structure:**
- Each line can contain one key-value pair
- Lines without `=` are treated as continuation lines (indented content)
- Empty lines are preserved in multiline values
- Whitespace-only input is an error

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

### Whitespace Handling Rules
**Sources:** Test Suite, Gleam Implementation, OCaml Reference

CCL uses specific whitespace handling rules that distinguish between different types of whitespace and different parsing contexts:

#### Character Types
- **Space character:** ` ` (ASCII 32)
- **Tab character:** `\t` (ASCII 9) 
- **Other whitespace:** Newlines, carriage returns, etc.

#### Key Processing
- **Remove all leading and trailing whitespace characters** from keys
- Applies to spaces, tabs, newlines, and other whitespace
- Keys are fully cleaned of whitespace

#### Value Processing  
- **Remove leading space characters only** from value start
- **Preserve all trailing whitespace characters** in final values
- This asymmetric processing prevents accidental content loss

#### Indentation Calculation
- **Count spaces and tabs only** for measuring line indentation levels
- Each space character = 1 indentation unit
- Each tab character = 1 indentation unit  
- Mixed tab/space indentation technically allowed but SHOULD generate warnings (see v1.2.0 consistency rules)

#### Continuation Line Processing
- **Remove trailing whitespace** from continuation lines during parsing
- **Preserve original indentation structure** in final multiline values
- Content within values keeps its intended whitespace

## 🚀 CORE PARSING ALGORITHM

**This is the essential step-by-step algorithm from the original CCL blog post:**

### Simple CCL Parsing Algorithm
**Source:** [Original Blog Post Algorithm](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html)

1. **Parse line by line, tracking indentation**

2. **Key parsing rules:**
   - Key = everything before the first `=`
   - Remove all leading and trailing whitespace characters from key (see Whitespace Handling Rules below)
   - Empty key after processing is allowed

3. **Value parsing rules:**
   - Value = everything after the `=`
   - Remove leading space characters only, preserve trailing whitespace characters (see Whitespace Handling Rules below)
   - Empty value after processing is allowed

4. **Indentation-sensitive parsing:**
   - Count leading indentation characters (spaces and tabs) `N` for the first key-value line
   - Each space character counts as 1 indentation unit, each tab character counts as 1 indentation unit
   - Lines with `≤ N` indentation units start a new key-value entry
   - Lines with `> N` indentation units continue the previous value
   - Mixed space/tab indentation is technically allowed (e.g., "  \t " = 4 indentation units) but SHOULD generate warnings
   - **Note**: v1.2.0 recommends consistent indentation style throughout a file

5. **Nested parsing approach:**
   - Recursively parse values as potential nested CCL configs
   - Stop parsing when no further nested parsing is possible
   - Reach a "fixed point" where parsing doesn't change the structure

**Key Principle:** "CCL does the smallest job possible, so the user can do the next smallest thing possible."

---

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

## Edge Cases

**Sources:** Test Suite, Gleam Implementation

CCL handles various edge cases during parsing:

1. **Empty Input:** Truly empty input returns empty result
2. **Whitespace-only Input:** Input containing only whitespace characters is an error condition
3. **Equals in Values:** Values can contain `=` characters - only the first `=` separates key from value
4. **Duplicate Keys:** Multiple entries with same key are preserved in order
5. **Base Indentation:** Base indentation level is determined by first non-empty line containing key-value pair
6. **Empty Keys:** Keys can be empty after whitespace trimming (used for lists)
7. **Empty Values:** Values can be empty (used for nested sections)

## Error Handling

**Sources:** Gleam Implementation, Test Suite

CCL implementations should handle these error conditions:

### Parse Errors
- **Line Numbers:** Error messages must include line number and reason
- **Context:** Provide enough context to help users locate the problem
- **Graceful Degradation:** Where possible, continue parsing to find multiple errors

### Common Error Types
1. **Continuation without Key:** Indented line without preceding key-value pair
2. **Invalid Structure:** Lines that don't conform to key-value or continuation patterns  
3. **Whitespace-only Input:** Input containing only whitespace characters
4. **Malformed Key-Value:** Lines with invalid syntax that can't be parsed

### Error Recovery
- Stop parsing on first structural error
- Preserve partial results where safe
- Report all found errors in batch where possible

## Outstanding Design Issues

### ⚠️ Visual vs Logical Indentation (RESOLVED in v1.2.0)

**Problem**: The character-by-character counting approach creates a mismatch between visual appearance and logical nesting levels, as tab stop widths vary across editors and users.

**Mathematical Impossibility**: There is no way to reconcile visual alignment when:
- Tab stops vary (4 vs 8 spaces)
- Indentation preferences differ (2 vs 4 spaces)
- Mixed tabs and spaces are used

**Resolution (v1.2.0)**: CCL maintains character-based counting for simplicity but strongly recommends consistent indentation:

#### Core Behavior (Unchanged)
- **1 space character = 1 indentation unit**
- **1 tab character = 1 indentation unit**
- Character-by-character counting, not visual/column-based

#### Indentation Consistency Rules (NEW)
1. **Pure Spaces**: ✅ Allowed and recommended
2. **Pure Tabs**: ✅ Allowed
3. **Mixed Indentation**: ⚠️ Warning (configurable to error)

**Implementation Guidance:**
```ccl
# GOOD - Pure spaces
config =
  host = localhost
  port = 5432

# GOOD - Pure tabs
config =
	host = localhost
	port = 5432

# WARNING - Mixed indentation for structure
config =
  host = localhost
	port = 5432     # Tab indentation mixed with space indentation
```

**Parser Behavior:**
- Core `parse()` function: Accepts all valid CCL including mixed indentation
- Strict mode `parse_strict()`: Warns or errors on mixed indentation
- Configuration flags may control strictness level

**Specification Language:**
- Implementations SHOULD detect mixed indentation styles
- Implementations SHOULD provide warnings for mixed indentation
- Implementations MAY provide strict mode to reject mixed indentation
- Future versions MAY make consistent indentation mandatory

**Rationale**: This approach:
- Preserves backward compatibility
- Provides clear guidance to users
- Allows gradual migration to stricter rules
- Maintains implementation simplicity

**Best Practices:**
1. Use spaces exclusively (recommended)
2. Configure editors to show whitespace characters
3. Use linting tools to enforce consistency
4. Convert tabs to spaces when sharing configurations

## Implementation Checklist

### Must-Have Features (Core Compliance)

Essential features for any CCL implementation:

- [ ] **Basic Key-Value Parsing** - Handle `key = value` pairs with proper trimming
- [ ] **Multiline Value Support** - Parse indentation-based value continuation
- [ ] **Empty Key/Value Handling** - Support empty keys (lists) and empty values (nested sections)
- [ ] **Nested Section Parsing** - Recursive parsing for hierarchical configurations
- [ ] **Fixed-Point Algorithm** - Proper object construction from flat entries
- [ ] **Order Preservation** - Maintain entry order including duplicates
- [ ] **Error Reporting** - Line number reporting for parse errors
- [ ] **Whitespace Rules** - Correct key/value trimming behavior

### Should-Have Features (Enhanced Compliance)

Recommended features for practical CCL usage:

- [ ] **Comment Filtering** - Filter entries by special keys (`/`, `#`, `//`)
- [ ] **Multi-line Key Support** - Handle keys split across lines
- [ ] **Mixed Indentation Handling** - Process tabs and spaces correctly
- [ ] **Mixed Indentation Detection** - Warn when tabs and spaces are mixed (v1.2.0)
- [ ] **Strict Parsing Mode** - Optional mode to reject mixed indentation (v1.2.0)
- [ ] **Edge Case Handling** - Proper behavior for empty input, whitespace-only input
- [ ] **Access APIs** - Convenient methods for querying nested data
- [ ] **Type Conversion** - String to basic type conversion utilities
- [ ] **Composition Operations** - Merge and combine configurations
- [ ] **Validation Tools** - Schema or structure validation support

### Optional Features (Extended Functionality)

Advanced features for specialized use cases:

- [ ] **Performance Optimization** - Streaming or lazy parsing for large files
- [ ] **Format Embedding** - Support for JSON/YAML values within CCL
- [ ] **Schema Validation** - Type-aware parsing and validation
- [ ] **IDE Integration** - Language server protocol support
- [ ] **Linting Tools** - Style and consistency checking
- [ ] **Migration Tools** - Convert from/to other configuration formats
- [ ] **Debugging Support** - Parse tree visualization and debugging
- [ ] **Watch Mode** - File system monitoring for configuration changes

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

## Mathematical Foundation

### Composition Properties
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

## Quick Reference Card

### Basic Syntax Cheat Sheet

```ccl
# Basic key-value pairs
name = My App
version = 1.0.0

# Empty values (nested sections)
database =
  host = localhost
  port = 5432

# Lists (empty keys)
items =
  = first item
  = second item
  = third item

# Lists (indexed keys)  
users =
  0 = alice
  1 = bob
  2 = charlie

# Multiline values (indented continuation)
description = This is a long description
  that continues on the next line
  and preserves indentation

# Multi-line keys
very long configuration key name
= value for the long key

# Comments (filterable by key)
/= This is a comment
#= Python-style comment
//= C-style comment
```

### Key Parsing Rules

| Rule | Description |
|------|-------------|
| **Key Separator** | First `=` separates key from value |
| **Key Trimming** | Remove all leading/trailing whitespace from keys |
| **Value Trimming** | Remove leading spaces only, preserve trailing whitespace |
| **Empty Keys** | Allowed (used for lists) |
| **Empty Values** | Allowed (used for nested sections) |
| **Duplicate Keys** | Allowed, order preserved |

### Indentation Rules

| Rule | Description |
|------|-------------|
| **Base Level** | Determined by first key-value line |
| **Continuation** | Lines indented beyond base level continue previous value |
| **Nesting** | Empty values with indented content create nested sections |
| **Mixed Indentation** | Each space = 1 unit, each tab = 1 unit |
| **Whitespace Preservation** | Original indentation maintained in final values |

### Common Patterns

```ccl
# Configuration object
server =
  host = 0.0.0.0
  port = 8080
  ssl =
    enabled = true
    cert = /path/to/cert.pem

# List of objects
environments =
  0 =
    name = development
    debug = true
  1 =
    name = production
    debug = false

# Mixed content with comments
/= API Configuration Section
api =
  /= The base URL for all API calls
  base_url = https://api.example.com
  
  /= Timeout in milliseconds
  timeout = 30000
```

---

*This specification is derived from analysis of the CCL blog post, OCaml reference implementation, language-agnostic test suite, and the Gleam implementation. It represents the current understanding of CCL behavior and serves as a guide for implementation consistency.*