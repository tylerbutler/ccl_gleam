# CCL High-Level Decode API Improvement Plan

**Version:** 1.0.0  
**Date:** 2025-01-02  
**Status:** Proposal

## Overview

This plan proposes adding a high-level decode API for CCL that provides type-safe, functional composition patterns similar to Gleam's JSON decode API. The goal is to make CCL configuration parsing more ergonomic and less error-prone.

## Current State vs. Target

### Current CCL Usage (Low-Level)
```gleam
// Manual string parsing with error handling
case ccl_core.parse(ccl_text) {
  Ok(entries) -> {
    let ccl_obj = ccl_core.build_hierarchy(entries)
    case ccl_core.get_value(ccl_obj, "database.host") {
      Ok(host_str) -> 
        case ccl_core.get_value(ccl_obj, "database.port") {
          Ok(port_str) ->
            case int.parse(port_str) {
              Ok(port) -> DatabaseConfig(host: host_str, port: port)
              Error(_) -> // Handle parse error
            }
          Error(_) -> // Handle missing key
        }
      Error(_) -> // Handle missing key  
    }
  }
  Error(_) -> // Handle CCL parse error
}
```

### Target High-Level API
```gleam
// Functional composition with automatic type conversion
let ccl_text = "
name = My App
database.host = localhost  
database.port = 5432
database.ssl = true
"

case decode_ccl(ccl_text, app_config_decoder()) {
  Ok(config) -> {
    // config.name: String
    // config.database.host: String  
    // config.database.port: Int
    // config.database.ssl: Bool
    use_config(config)
  }
  Error(error) -> handle_decode_error(error)
}
```

## Core Design Principles

### 1. Handle CCL's Simple Key-Value Reality
CCL has one fundamental approach: **everything is key-value pairs with string keys**.

**Important:** `database.host` is a **literal string key**, NOT navigation syntax. CCL has no special handling for dots.

**Flat Keys (Literal Strings):**
```ccl
database.host = localhost
database.port = 5432  
user.settings.theme = dark
```
Creates three separate string keys: `"database.host"`, `"database.port"`, `"user.settings.theme"`

**Nested Structure (Indentation-Based):**
```ccl
database =
  host = localhost
  port = 5432
```
Creates nested CCL objects through indented continuation lines.

**The API Design Choice:** Should we provide convenience functions to split dotted keys and treat them as navigation paths? This would be **API sugar, not CCL functionality**.

### 2. Functional Composition (Gleam-Style)
Follow Gleam's established patterns for decoders:

```gleam
// Define decoder functions
pub fn database_config_decoder() -> Decoder(DatabaseConfig) {
  use host <- field("host", string_decoder())
  use port <- field("port", int_decoder()) 
  use ssl <- field("ssl", bool_decoder())
  success(DatabaseConfig(host:, port:, ssl:))
}
```

### 3. Comprehensive Type Support
- ✅ **String** - Direct value access
- ✅ **Int** - Parse with `int.parse()` 
- ✅ **Bool** - Support multiple formats (`true/false`, `yes/no`, `1/0`, `on/off`)
- ✅ **Float** - Parse with `float.parse()`
- ✅ **Optional** - Handle missing keys gracefully
- 🔄 **List** - Extract CCL list syntax (empty keys)
- 🔄 **Nested Objects** - Navigate nested CCL structures

## Implementation Architecture

### Type System
```gleam
pub type DecodeError {
  FieldNotFound(field: String, path: String)
  TypeMismatch(expected: String, found: String, path: String)
  InvalidFormat(value: String, expected_type: String, path: String)
  ParseError(reason: String)
}

pub type Decoder(a) = fn(ccl_core.CCL, String) -> Result(a, DecodeError)
```

### Core Decoder Functions
```gleam
// Basic type decoders
pub fn string_decoder() -> Decoder(String)
pub fn int_decoder() -> Decoder(Int)
pub fn bool_decoder() -> Decoder(Bool)
pub fn float_decoder() -> Decoder(Float)

// Composition functions
pub fn field(name: String, decoder: Decoder(a)) -> Decoder(a)
pub fn optional_field(name: String, decoder: Decoder(a)) -> Decoder(Option(a))
pub fn list_decoder(item_decoder: Decoder(a)) -> Decoder(List(a))
pub fn success(value: a) -> Decoder(a)

// Main decode function
pub fn decode_ccl(ccl_text: String, decoder: Decoder(a)) -> Result(a, String)
```

### Path Resolution Strategy

The API needs to decide how to handle field access. Two approaches:

**Approach 1: Literal Keys Only (True to CCL)**
```gleam
// Direct key lookup - no interpretation of dots
fn resolve_field_literal(ccl: CCL, base_path: String, field_name: String) -> Result(String, DecodeError) {
  let full_key = case base_path {
    "" -> field_name
    _ -> base_path <> "." <> field_name
  }
  
  // Direct lookup of the literal key
  case ccl_core.get_value(ccl, full_key) {
    Ok(value) -> Ok(value)
    Error(_) -> Error(FieldNotFound(field_name, full_key))
  }
}
```

**Approach 2: Navigation Sugar (API Convenience)**
```gleam  
// Try both literal keys and navigation for convenience
fn resolve_field_with_navigation(ccl: CCL, base_path: String, field_name: String) -> Result(String, DecodeError) {
  let full_path = case base_path {
    "" -> field_name
    _ -> base_path <> "." <> field_name
  }
  
  // Strategy 1: Try literal key first (most direct)
  case ccl_core.get_value(ccl, full_path) {
    Ok(value) -> Ok(value)
    Error(_) -> {
      // Strategy 2: Try navigation (API convenience)
      case ccl_core.get_nested(ccl, base_path) {
        Ok(nested) -> 
          case ccl_core.get_value(nested, field_name) {
            Ok(value) -> Ok(value)
            Error(_) -> Error(FieldNotFound(field_name, full_path))
          }
        Error(_) -> Error(FieldNotFound(field_name, full_path))
      }
    }
  }
}
```

**Recommendation:** Start with Approach 1 (literal keys) to stay true to CCL's simplicity, then consider Approach 2 as an optional convenience feature.

## Usage Examples

### Simple Configuration
```gleam
pub type AppConfig {
  AppConfig(name: String, debug: Bool, version: String)
}

pub fn app_config_decoder() -> Decoder(AppConfig) {
  use name <- field("name", string_decoder())
  use debug <- field("debug", bool_decoder())
  use version <- field("version", string_decoder())
  success(AppConfig(name:, debug:, version:))
}

// Usage
let ccl_text = "name = MyApp\ndebug = true\nversion = 1.0.0"
case decode_ccl(ccl_text, app_config_decoder()) {
  Ok(config) -> // Fully typed AppConfig
  Error(error) -> // Handle decode error
}
```

### Nested Configuration
```gleam
pub type DatabaseConfig {
  DatabaseConfig(host: String, port: Int, ssl: Bool, timeout: Option(Int))
}

pub type ServerConfig {
  ServerConfig(name: String, database: DatabaseConfig)
}

pub fn database_config_decoder() -> Decoder(DatabaseConfig) {
  use host <- field("host", string_decoder())
  use port <- field("port", int_decoder())
  use ssl <- field("ssl", bool_decoder())
  use timeout <- optional_field("timeout", int_decoder())
  success(DatabaseConfig(host:, port:, ssl:, timeout:))
}

pub fn server_config_decoder() -> Decoder(ServerConfig) {
  use name <- field("name", string_decoder())
  use database <- field("database", database_config_decoder())
  success(ServerConfig(name:, database:))
}
```

**Option 1: Flat Keys (Literal String Keys)**
```gleam
// These are separate string keys - NOT navigation
let flat_ccl = "
name = MyServer
database.host = localhost
database.port = 5432
database.ssl = true
"

// Decoder would need to be aware of the literal keys:
pub fn flat_database_config_decoder() -> Decoder(DatabaseConfig) {
  use host <- field("database.host", string_decoder())     // Literal key
  use port <- field("database.port", int_decoder())       // Literal key  
  use ssl <- field("database.ssl", bool_decoder())        // Literal key
  use timeout <- optional_field("database.timeout", int_decoder())
  success(DatabaseConfig(host:, port:, ssl:, timeout:))
}
```

**Option 2: True Nested Structure** 
```gleam
// This creates actual nested CCL objects
let nested_ccl = "
name = MyServer
database =
  host = localhost
  port = 5432
  ssl = true
"

// Standard nested decoder works here:
case decode_ccl(nested_ccl, server_config_decoder()) {
  Ok(config) -> // Properly typed ServerConfig
  Error(error) -> // Handle error
}
```

**Key Point:** These are **different CCL structures** requiring **different decoders**. The API cannot magically treat them the same without making assumptions about key naming conventions.

## Implementation Phases

### Phase 1: Core Infrastructure ✅
- [x] Basic decoder types and error handling
- [x] String, Int, Bool decoders
- [x] Field composition patterns
- [x] Main decode function
- [x] Proof of concept working

### Phase 2: Path Resolution Strategy
- [ ] Implement dual path resolution (flat + nested)
- [ ] Add comprehensive error messages with path context
- [ ] Handle edge cases and conflicts
- [ ] Add thorough test coverage

### Phase 3: Advanced Features
- [ ] List decoder implementation
- [ ] Float decoder
- [ ] Custom decoder combinators
- [ ] Optional fields with default values
- [ ] Recursive decoder support

### Phase 4: Polish & Documentation
- [ ] Performance optimization
- [ ] Comprehensive documentation
- [ ] Example cookbook
- [ ] Migration guide from low-level API

## Benefits

### Developer Experience
- **Type Safety:** Compile-time guarantees for config structure
- **Error Messages:** Clear, contextual error reporting
- **Composability:** Build complex decoders from simple parts
- **Familiarity:** Follows established Gleam JSON decode patterns

### CCL Compatibility
- **Full Spec Compliance:** Treats keys as literal strings per CCL specification
- **No Magic:** Doesn't impose interpretation on key names (including dots)
- **Explicit:** Requires developers to choose between flat keys vs nested structure
- **True to CCL:** Maintains the language's philosophical simplicity

### Maintainability  
- **Functional Composition:** Decoders are easy to test and modify
- **Separation of Concerns:** Type conversion separate from parsing
- **Extensible:** Easy to add new decoder types

## Future Extensions

### Advanced Decoders
```gleam
pub fn url_decoder() -> Decoder(Uri)
pub fn date_decoder() -> Decoder(Date)  
pub fn enum_decoder(variants: List(String)) -> Decoder(CustomEnum)
```

### Validation
```gleam
pub fn validated_field(name: String, decoder: Decoder(a), validator: fn(a) -> Bool) -> Decoder(a)
```

### Schema Generation
```gleam
pub fn generate_schema(decoder: Decoder(a)) -> JsonSchema
```

## Conclusion

This high-level decode API would significantly improve the CCL developer experience while maintaining full fidelity to the CCL specification. By treating keys as literal strings (as CCL does) and providing clear, explicit decoder patterns, it preserves CCL's philosophical simplicity while adding type safety and ergonomic composition patterns.

The implementation follows proven Gleam patterns, making it immediately familiar to Gleam developers while staying true to CCL's minimalist, string-based design. Developers can choose between flat string keys or nested structures based on their needs, with the API supporting both approaches transparently.