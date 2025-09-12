# Typed Parsing - IMPLEMENTED ✅

## Overview

Type-aware parsing is **fully implemented** as an optional layer on top of the core CCL string-based functionality. Core CCL remains unchanged (everything as strings), with type inference provided by new functions that parse strings into typed values.

## Architecture

### Core CCL Layer (Unchanged)
- All existing functions remain as-is, returning strings
- `get_value()`, `get_values()`, `node_type()` continue to work with strings only
- Internal CCL representation stays the same (nested maps with string values)

### Type Inference Layer (New)
- New functions that call core CCL functions and parse the returned strings
- Optional layer - users can choose to use typed parsing or stick with strings
- Clean separation of concerns

## API Design

### Core Types
```gleam
pub type ValueType {
  StringVal(String)
  IntVal(Int) 
  FloatVal(Float)
  BoolVal(Bool)
  EmptyVal           // for "key =" with no value
}

pub type ParseOptions {
  ParseOptions(
    parse_integers: Bool,
    parse_floats: Bool,
    parse_booleans: Bool,
  )
}
```

### Implemented API Functions ✅
```gleam
// Available in packages/ccl/src/ccl.gleam

// Options presets
pub fn basic_options() -> ParseOptions     // no parsing (all False)  
pub fn smart_options() -> ParseOptions    // all parsing enabled (all True)

// Primary typed access
pub fn get_int(ccl: CCL, path: String) -> Result(Int, String)
pub fn get_float(ccl: CCL, path: String) -> Result(Float, String)
pub fn get_bool(ccl: CCL, path: String) -> Result(Bool, String)

// Generic typed access with automatic type inference
pub fn get_typed_value(ccl: CCL, path: String) -> Result(ValueType, String)
pub fn get_typed_value_with_options(ccl: CCL, path: String, options: ParseOptions) -> Result(ValueType, String)
```

### Implementation Strategy
```gleam
pub fn get_int(ccl: CCL, path: String) -> Result(Int, String) {
  use str_val <- result.try(get_value(ccl, path))  // Call existing core function
  parse_int(str_val)  // Parse string to int
}
```

## Parsing Logic

### Integer Parsing
```gleam
fn parse_int(value: String) -> Result(Int, String) {
  let trimmed = string.trim(value)
  case string.to_int(trimmed) {
    Ok(n) -> Ok(n)
    Error(_) -> Error("Cannot parse '" <> value <> "' as integer")
  }
}
```

**Examples:**
- `"2"` → `Ok(2)`
- `" 42 "` → `Ok(42)`  
- `"2.5"` → `Error("Cannot parse '2.5' as integer")`
- `"abc"` → `Error("Cannot parse 'abc' as integer")`

### Float Parsing  
```gleam
fn parse_float(value: String) -> Result(Float, String) {
  let trimmed = string.trim(value)
  case string.to_float(trimmed) {
    Ok(f) -> Ok(f)
    Error(_) -> Error("Cannot parse '" <> value <> "' as float")
  }
}
```

**Examples:**
- `"2.5"` → `Ok(2.5)`
- `"42"` → `Ok(42.0)`
- `" 3.14 "` → `Ok(3.14)`
- `"abc"` → `Error("Cannot parse 'abc' as float")`

### Boolean Parsing
```gleam
fn parse_bool(value: String) -> Result(Bool, String) {
  let trimmed = string.trim(string.lowercase(value))
  case trimmed {
    "true" | "yes" | "on" | "1" -> Ok(True)
    "false" | "no" | "off" | "0" -> Ok(False)
    _ -> Error("Cannot parse '" <> value <> "' as boolean")
  }
}
```

**Examples:**  
- `"true"` → `Ok(True)`
- `"YES"` → `Ok(True)`
- `"false"` → `Ok(False)`
- `" on "` → `Ok(True)`
- `"maybe"` → `Error("Cannot parse 'maybe' as boolean")`

### Generic Typed Parsing
```gleam
pub fn get_typed_value_with_options(ccl: CCL, path: String, options: ParseOptions) -> Result(ValueType, String) {
  case get_value(ccl, path) {
    Ok("") -> Ok(EmptyVal)
    Ok(str_val) -> {
      // Try parsing in order based on options
      case options.parse_integers, try_parse_int(str_val) {
        True, Ok(n) -> Ok(IntVal(n))
        _, _ -> case options.parse_floats, try_parse_float(str_val) {
          True, Ok(f) -> Ok(FloatVal(f))
          _, _ -> case options.parse_booleans, try_parse_bool(str_val) {
            True, Ok(b) -> Ok(BoolVal(b))
            _, _ -> Ok(StringVal(str_val))
          }
        }
      }
    }
    Error(err) -> Error(err)
  }
}
```

## Usage Examples

### Basic Type-Aware Access
```gleam
// Simple CCL config
let ccl_text = "login = chshersh\nhowManyYears = 2\nenabled = true"
let ccl_obj = ccl.build_hierarchy(ccl.parse(ccl_text))

// Core CCL (strings only) - unchanged
let login = ccl.get_value(ccl_obj, "login")        // Ok("chshersh")

// Type-aware access with smart defaults
let years = ccl.get_int(ccl_obj, "howManyYears")   // Ok(2)
let enabled = ccl.get_bool(ccl_obj, "enabled")     // Ok(True)

// Generic typed access
case ccl.get_typed_value(ccl_obj, "howManyYears") {
  Ok(IntVal(n)) -> io.println("Years: " <> string.inspect(n))
  Ok(StringVal(s)) -> io.println("Not parsed as number: " <> s)
  Error(err) -> handle_error(err)
}
```

### Custom Parsing Options
```gleam
// Conservative parsing - only integers, no floats or booleans
let conservative_options = ParseOptions(
  parse_integers: True, 
  parse_floats: False, 
  parse_booleans: False
)

let years = ccl.get_int_with_options(ccl_obj, "howManyYears", conservative_options)
let value = ccl.get_typed_value_with_options(ccl_obj, "someValue", conservative_options)
```

## Edge Cases and Open Questions

### 1. Whitespace Handling
**Question:** How should whitespace-only values be handled?

**Options:**
- **A)** `"   "` → `StringVal("   ")` (preserve as string)
- **B)** `"   "` → `EmptyVal` (treat as empty after trimming)

**Recommendation:** Option A - preserve whitespace-only as strings to maintain user intent.

### 2. Number Precedence
**Question:** If both integer and float parsing are enabled, what should `"42"` become?

**Options:**
- **A)** Try integer first: `"42"` → `IntVal(42)`
- **B)** Try float first: `"42"` → `FloatVal(42.0)`
- **C)** Context-dependent: if any sibling value is a float, all become floats

**Recommendation:** Option A - try integer first since it's more specific. Users can disable integer parsing if they want everything as floats.

### 3. Empty String Handling
**Question:** How should completely empty values be handled?

**Current Plan:** `""` → `EmptyVal`

**Consideration:** Should distinguish between `"key ="` (empty value) and `"key = "` (space value)?

### 4. Error Message Context
**Question:** Should error messages include the path for better debugging?

**Options:**
- **A)** `"Cannot parse 'abc' as integer"`
- **B)** `"Cannot parse 'abc' as integer at path 'server.port'"`

**Recommendation:** Option B for better debugging, especially in complex configurations.

### 5. Mixed-Type Lists
**Question:** How should lists with mixed types be handled in `get_typed_value()`?

**Example:**
```ccl
values =
  = 1
  = 2.5  
  = true
```

**Current Plan:** Allow mixed types: `[IntVal(1), FloatVal(2.5), BoolVal(True)]`

**Consideration:** Should there be type-specific list getters like `get_int_list()` that enforce homogeneous types?

### 6. Boolean Value Configurability
**Question:** Should boolean true/false values be configurable?

**Current Plan:** Fixed set: `["true", "yes", "on", "1"]` for true, `["false", "no", "off", "0"]` for false.

**Future Enhancement:** Could add to ParseOptions:
```gleam
ParseOptions(
  parse_booleans: Bool,
  true_values: List(String),
  false_values: List(String),
)
```

### 7. Scientific Notation and Special Numbers
**Question:** Should we support scientific notation for floats? Special values like infinity/NaN?

**Examples:**
- `"1.5e10"` → `FloatVal(15000000000.0)`
- `"inf"` → `FloatVal(positive_infinity)`
- `"nan"` → `FloatVal(nan)`

**Current Plan:** Let Gleam's `string.to_float()` handle what it supports natively.

### 8. Numeric Edge Cases
**Question:** How should edge cases be handled?

**Examples:**
- `"0x42"` (hexadecimal) → Currently would fail integer parsing
- `"+42"` (explicit positive) → Should work with `string.to_int()`
- `"42."` (trailing decimal) → Should work with `string.to_float()`

**Current Plan:** Rely on Gleam's built-in parsing behavior for consistency.

## Implementation Priority

1. **Phase 1:** Basic integer, float, boolean parsing with smart defaults
2. **Phase 2:** Custom ParseOptions and `_with_options()` variants
3. **Phase 3:** Generic `get_typed_value()` function
4. **Phase 4:** Address edge cases and add enhanced error messages
5. **Phase 5:** Consider advanced features (configurable boolean values, etc.)

## Benefits

- **✅ Clean Architecture:** Type parsing as optional layer over string-based core
- **✅ No Breaking Changes:** Existing CCL code continues to work unchanged  
- **✅ Type Safety:** Proper Gleam types for parsed values (Int, Float, Bool)
- **✅ Flexible:** Users can opt into the level of parsing they need
- **✅ Consistent:** Uses Gleam's built-in parsing functions for reliability
- **✅ Extensible:** Easy to add new types or parsing options in the future