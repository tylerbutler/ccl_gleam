# CCL Gleam - Developer Guide

This document provides detailed information about the CCL (Categorical Configuration Language) implementation in Gleam, including the API design, algorithm details, and implementation notes.

## Architecture Overview

The CCL implementation follows a two-phase approach based on the OCaml reference implementation:

1. **Phase 1: Flat Parsing** - Parse CCL text into flat key-value pairs
2. **Phase 2: Object Construction** - Apply fixpoint algorithm to build nested structures

## Public API

### Core Functions

```gleam
// Main parsing function - entry point for users
pub fn parse(text: String) -> Result(List(Entry), ParseError)

// Object construction from flat entries using fixpoint algorithm
pub fn make_objects(entries: List(Entry)) -> CCL

// Helper functions for working with CCL objects
pub fn pretty_print_ccl(ccl: CCL) -> String
pub fn merge_ccl(ccl1: CCL, ccl2: CCL) -> CCL
pub fn empty_ccl() -> CCL
```

### Data Types

```gleam
// Flat key-value pair (output of parse)
pub type Entry {
  Entry(key: String, value: String)
}

// Parse errors with line number and reason
pub type ParseError {
  ParseError(line: Int, reason: String)
}

// Recursive CCL structure (equivalent to OCaml's type t = Fix of t Map.t)
pub type CCL {
  CCL(map: dict.Dict(String, CCL))
}
```

## Internal Implementation

### Private Functions

```gleam
// Used internally by make_objects during fixpoint algorithm
fn parse_value(text: String) -> Result(List(Entry), ParseError)
```

### Key Differences: `parse` vs `parse_value`

Even though both functions have the same signature, they serve different purposes:

| Aspect | `parse` | `parse_value` |
|--------|---------|---------------|
| **Purpose** | Parse complete CCL documents | Parse individual values that may contain nested CCL |
| **Visibility** | Public API | Private implementation detail |
| **Context** | Top-level document parsing | Internal recursive parsing during object construction |
| **Input expectations** | Complete CCL files/documents | Value content (often indented) |
| **Indentation handling** | Uses first key-value pair to determine base indentation | Finds first non-empty line to determine base indentation |
| **Error handling** | Requires at least one key-value pair with `=` | Can handle empty input (returns empty list) |

## `make_objects` Function - Detailed Explanation

The `make_objects` function implements the core CCL fixpoint algorithm that converts flat key-value pairs into a recursive nested structure.

### Algorithm Steps

1. **Group entries by key** - Handle multiple values per key
2. **Recursive value parsing** - Try to parse each value as nested CCL
3. **Fixpoint convergence** - Keep parsing until no more changes occur
4. **Merge structures** - Combine entries with the same key

### Detailed Example

Let's trace through a complex example:

**Input CCL:**
```ccl
user =
  name = alice

user =
  age = 25
  
database =
  host = localhost
  ports =
    = 8000
    = 8001

simple = value
```

#### Step 1: `parse` Function Processing

```gleam
case ccl.parse(input) {
  Ok(flat_entries) -> // Result shown below
}
```

**Flat entries from `parse`:**
```gleam
[
  Entry("user", "\n  name = alice"),
  Entry("user", "\n  age = 25"), 
  Entry("database", "\n  host = localhost\n  ports =\n    = 8000\n    = 8001"),
  Entry("simple", "value")
]
```

#### Step 2: `make_objects` Processing

##### 2.1 Group entries by key:
```gleam
{
  "user" -> ["\n  name = alice", "\n  age = 25"],
  "database" -> ["\n  host = localhost\n  ports =\n    = 8000\n    = 8001"], 
  "simple" -> ["value"]
}
```

##### 2.2 Convert to ValueEntry (recursive parsing):

For each value, try `parse_value()` internally:

**`"simple"` -> `"value"`:**
- `parse_value("value")` fails (no `=` sign)
- Result: `StringValue("value")`

**`"user"` -> `"\n  name = alice"`:**
- `parse_value("\n  name = alice")` succeeds!  
- Parses to: `[Entry("name", "alice")]`
- Result: `NestedCCL({"name" -> [StringValue("alice")]})`

**`"user"` -> `"\n  age = 25"`:**
- `parse_value("\n  age = 25")` succeeds!
- Parses to: `[Entry("age", "25")]`
- Result: `NestedCCL({"age" -> [StringValue("25")]})`

**`"database"` -> `"\n  host = localhost\n  ports =\n    = 8000\n    = 8001"`:**
- `parse_value(...)` succeeds!
- Parses to: `[Entry("host", "localhost"), Entry("ports", "\n    = 8000\n    = 8001")]`
- **Recursive parsing continues** for `"ports"` value:
  - `parse_value("\n    = 8000\n    = 8001")` succeeds!
  - Parses to: `[Entry("", "8000"), Entry("", "8001")]`
- Result: `NestedCCL({...})`

##### 2.3 Apply fixpoint algorithm:

**First iteration results:**
```gleam
{
  "simple": StringValue("value"),
  "user": [
    NestedCCL({"name" -> [StringValue("alice")]}),
    NestedCCL({"age" -> [StringValue("25")]})
  ],
  "database": NestedCCL({
    "host" -> [StringValue("localhost")],
    "ports" -> [NestedCCL({
      "" -> [StringValue("8000"), StringValue("8001")]
    })]
  })
}
```

##### 2.4 Build final CCL structure:

Convert `ValueEntry` to `CCL` and merge duplicates:

```gleam
CCL({
  "simple": CCL({"" : CCL({"value": CCL({})})}),
  "user": CCL({
    "name": CCL({"": CCL({"alice": CCL({})})}),
    "age": CCL({"": CCL({"25": CCL({})})})
  }),
  "database": CCL({
    "host": CCL({"": CCL({"localhost": CCL({})})}),
    "ports": CCL({
      "": CCL({
        "8000": CCL({}),
        "8001": CCL({})
      })
    })
  })
})
```

### Key Differences: `parse` vs `make_objects`

| Aspect | `parse` | `make_objects` |
|--------|---------|----------------|
| **Input** | Raw CCL text | List of Entry |
| **Output** | Flat key-value pairs | Nested CCL structure |
| **Processing** | Syntax parsing only | Recursive value parsing + merging |
| **Duplicates** | Kept as separate entries | Merged into single structure |
| **Nesting** | Values remain as strings | Values parsed recursively |

### Duplicate Key Merging Strategy

CCL handles duplicate keys differently at different abstraction levels:

#### Core Level (Flat Parsing)
- **Behavior**: Preserves all entries in order (maintains semigroup/monoid properties)
- **Implementation**: `group_entries_by_key()` accumulates values in latest-first order
- **Example**: `user = alice\nuser = bob` → Two separate entries preserved

#### Higher Level (Object Construction) 
- **Nested Objects**: Deep merge strategy - combines fields from duplicate keys recursively
- **List Structures**: Accumulation - collects values with empty keys into arrays
- **Implementation**: `merge_ccl()` performs recursive deep merge of CCL structures

**Deep Merge Example:**
```ccl
user =
  name = alice
user =
  age = 25
```
**Result**: Single merged object with both fields:
```gleam
CCL({
  "user": CCL({
    "": CCL({
      "name": CCL({}),  // Terminal: "alice"
      "age": CCL({})    // Terminal: "25"
    })
  })
})
```

**List Accumulation Example:**
```ccl
ports =
  = 8000
  = 8001
  = 8002
```
**Result**: Array structure using empty keys:
```gleam
CCL({
  "ports": CCL({
    "": CCL({
      "8000": CCL({}),  // First element
      "8001": CCL({}),  // Second element  
      "8002": CCL({})   // Third element
    })
  })
})
```

**Key Insight**: Empty keys (`""`) act as array indices, enabling list-like structures while maintaining CCL's uniform key-value model.

### Example Output Comparison

**`parse` output (flat):**
```gleam
[
  Entry("user", "\n  name = alice"),
  Entry("user", "\n  age = 25")  // Duplicate key kept separate
]
```

**`make_objects` output (nested):**
```gleam
CCL({
  "user": CCL({
    "name": CCL({"": CCL({"alice": CCL({})})}),
    "age": CCL({"": CCL({"25": CCL({})})})  // Merged with first user entry
  })
})
```

### When Fixpoint Converges

The algorithm stops when `parse_value()` can't parse any more values:

1. **"value"** - no `=`, stops immediately
2. **"alice"** - no `=`, stops  
3. **"25"** - no `=`, stops
4. **"localhost"** - no `=`, stops
5. **"8000", "8001"** - no `=`, stop

**Result:** All terminal values reached, fixpoint achieved.

## Usage Pattern

```gleam
// 1. Parse flat structure
case ccl.parse(ccl_text) {
  Ok(flat_entries) -> {
    // 2. Build nested objects  
    let nested_ccl = ccl.make_objects(flat_entries)
    
    // 3. Use nested structure
    ccl.pretty_print_ccl(nested_ccl)
  }
  Error(err) -> // handle parse error
}
```

## Implementation Notes

### Design Benefits

1. **Clean separation**: Users only see what they need (`parse` and `make_objects`)
2. **Implementation flexibility**: Internal functions can change without breaking user code  
3. **Clear intent**: `parse_value` being private makes it clear it's an implementation detail
4. **Proper encapsulation**: The fixpoint algorithm details are hidden
5. **Backward compatibility**: All existing flat parsing functionality is preserved

### Recursive Structure Rationale

The CCL structure `CCL(dict.Dict(String, CCL))` creates a recursive map where:
- Each key maps to another CCL structure
- Terminal values are represented as `key -> "" -> value -> {}`
- Empty keys (`""`) are used for list-style structures
- The structure matches the OCaml reference implementation's `type t = Fix of t Map.t`

#### Detailed Structure Analysis

**Design Principles:**

1. **Uniform Representation**: Everything is a map, even terminal values
2. **Empty Key Convention**: Terminal values use `""` (empty string) as a key
3. **Recursive Nesting**: Maps can contain other maps arbitrarily deep

**Terminal Value Encoding:**

Simple values like `simple = value` become:
```gleam
CCL({
  "simple": CCL({
    "": CCL({
      "value": CCL({})  // Empty map = terminal
    })
  })
})
```

The access path is: `"simple" → "" → "value" → {}`

**Nested Object Encoding:**

Nested structures like:
```ccl
user =
  name = alice
  age = 25
```

Become:
```gleam
CCL({
  "user": CCL({
    "name": CCL({
      "": CCL({
        "alice": CCL({})  // Terminal: alice
      })
    }),
    "age": CCL({
      "": CCL({
        "25": CCL({})     // Terminal: 25
      })
    })
  })
})
```

**List/Array Encoding:**

List structures using empty keys:
```ccl
ports =
  = 8000
  = 8001
  = 8002
```

Become:
```gleam
CCL({
  "ports": CCL({
    "": CCL({
      "8000": CCL({}),  // First element
      "8001": CCL({}),  // Second element  
      "8002": CCL({})   // Third element
    })
  })
})
```

**Why This Structure:**

1. **Mathematical Foundation**: Matches OCaml's `type t = Fix of t Map.t` (fixed-point of maps)
2. **Uniform Access**: Every lookup follows the same pattern regardless of nesting level
3. **Compositionality**: Easy to merge structures using map operations
4. **Type Safety**: No special cases - everything follows the same recursive pattern

**Navigation Pattern:**

To access `user.name`:
1. Start with root CCL
2. Look up `"user"` → get CCL
3. Look up `"name"` → get CCL  
4. Look up `""` → get CCL
5. Keys in final map are the actual values (`"alice"`)

The empty key `""` acts as a **value container** - it separates the navigation structure from the actual terminal values.

### Testing Strategy

The implementation includes comprehensive test coverage:
- **53 core flat parsing tests** - ensure backward compatibility
- **Error condition tests** - validate proper error handling  
- **Nested structure tests** - verify object construction behavior
- **JSON test definitions** - language-agnostic test cases for cross-implementation validation

#### Algebraic Properties Testing

CCL's mathematical foundation requires testing monoid and semigroup properties:

**Identity Element Decision**: We use **Semantic Empty** (empty entry list `[]`) as the monoid identity rather than strict empty strings or whitespace-tolerant empty inputs. Alternatives considered:
- *Strict Empty*: Only literal `""` - too brittle for real-world config composition
- *Whitespace-Tolerant*: Empty or whitespace-only inputs - introduces normalization complexity
- *Semantic Empty*: No entries after parsing - most practical and mathematically sound

**Test Level Separation**: Following CCL's design philosophy that higher-level semantics are defined outside the core:
- **Core Level**: Entry list concatenation, parsing invariants, text-level composition stability
- **Higher Level**: Object construction, key merging strategies (currently accumulates, needs review), nested structure handling

**Testing Approach**: Fixed comprehensive test cases in JSON format rather than property-based testing. Alternatives considered:
- *QuickCheck-style*: Would require building generator infrastructure in Gleam
- *Hybrid approach*: Fixed cases + generated - more complex to maintain
- *Fixed cases*: Fits existing infrastructure, deterministic, can exhaustively cover core properties

### Performance Considerations

- **Lazy evaluation**: `parse_value` is only called when needed during object construction
- **Memoization opportunity**: The fixpoint algorithm could benefit from caching parse results
- **Memory efficiency**: Terminal values could be optimized to avoid deep nesting

## Development Workflow

1. **Core parsing** remains unchanged - maintains all existing functionality
2. **Object construction** is optional - users can work with flat entries if preferred
3. **Extension point** - new CCL features can be added to object construction without affecting parsing
4. **Language portability** - the JSON test suite enables validation across different language implementations

This two-step process separates syntax parsing from semantic object construction, making both easier to understand and test independently while maintaining full compatibility with the CCL specification and reference implementation.

## Frequently Asked Questions

### Q: Why does the CCL structure use empty keys (`""`)?

**A:** This is a common point of confusion when examining the internal CCL structure. The empty key `""` serves as a **"value container marker"**.

**The Problem:** CCL's internal structure is uniform - everything must be a map (`CCL(dict.Dict(String, CCL))`). But terminal values like `"alice"` aren't maps, they're just strings.

**The Solution:** The empty key `""` means **"this is where the actual value lives"**.

```gleam
// name = alice becomes:
CCL({
  "name": CCL({           // Navigate to "name" 
    "": CCL({             // Empty key = "here's the value"
      "alice": CCL({})    // The actual value "alice"
    })
  })
})
```

**Think of it as three layers:**
1. **Navigation layer**: `"name"` - tells you which field
2. **Value container layer**: `""` - says "the value is in here" 
3. **Value layer**: `"alice"` - the actual terminal value

**Why not just store strings directly?** The structure could theoretically be `Dict(String, String | CCL)` but that would:
- Break uniformity (sometimes string, sometimes CCL)
- Make merging complex (different types to handle) 
- Lose mathematical elegance (no longer a pure recursive map)

**Key insight:** When you see `"": CCL({"alice": CCL({})})`, read it as:
- `""` = "here are the values"
- `"alice"` = the actual value
- `CCL({})` = end of recursion

**Important:** Users never interact with this directly - the API functions handle all the complexity of navigating these structures.

### Q: Do I need to understand the internal CCL structure?

**A:** No! The complex recursive structure is an implementation detail. Users work with the clean public API:

```gleam
// Simple user workflow:
case ccl.parse(ccl_text) {
  Ok(entries) -> {
    let nested = ccl.make_objects(entries)
    ccl.pretty_print_ccl(nested)
  }
  Error(err) -> // handle error
}
```

The internal representation enables powerful features like merging and pretty-printing, but you just call the provided functions.

## Known Issues & TODOs

### ✅ FIXED: Tab Indentation Support

**Status**: RESOLVED - Tab indentation is now fully supported.

**Fix Applied**: Function `count_leading_spaces_helper()` now correctly handles both spaces and tabs:
```gleam
fn count_leading_spaces_helper(graphemes: List(String), count: Int) -> Int {
  case graphemes {
    [] -> count
    [" ", ..rest] -> count_leading_spaces_helper(rest, count + 1)  // Space
    ["\t", ..rest] -> count_leading_spaces_helper(rest, count + 1)  // Tab ✅ FIXED
    _ -> count
  }
}
```

**Compatibility**: Now fully compatible with OCaml reference implementation for indentation handling.