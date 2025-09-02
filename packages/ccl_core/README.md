# CCL Core

[![Package Version](https://img.shields.io/hexpm/v/ccl_core)](https://hex.pm/packages/ccl_core)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl_core/)

Minimal CCL parsing library with zero external dependencies. For enhanced features, see the [`ccl`](https://hex.pm/packages/ccl) package.

## Installation

Add `ccl_core` to your Gleam project:

```sh
gleam add ccl_core
```

## What is CCL?

CCL is a minimal configuration format using key-value pairs with indentation-based nesting:

```
database =
  host = localhost
  port = 5432
```

For the specification, see: https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html

## Quick Start

```gleam
import ccl_core

// Parse CCL text into flat key-value pairs
let ccl_text = "
database =
  host = localhost  
  port = 5432
  credentials =
    username = admin
    password = secret123

server =
  ports =
    = 8000
    = 8001
    = 8002
"

case ccl_core.parse(ccl_text) {
  Ok(entries) -> {
    // Build nested CCL object using fixpoint algorithm
    let ccl_obj = ccl_core.make_objects(entries)
    
    // Access nested values with dot notation
    case ccl_core.get_value(ccl_obj, "database.host") {
      Ok(host) -> io.println("Database host: " <> host)
      Error(err) -> io.println("Error: " <> err)
    }
    
    // Access list values (using empty keys)
    let ports = ccl_core.get_values(ccl_obj, "server.ports")
    io.println("Server ports: " <> string.join(ports, ", "))
  }
  Error(parse_error) -> {
    io.println("Parse error on line " <> int.to_string(parse_error.line) <> ": " <> parse_error.reason)
  }
}
```

## Core API

### Parsing and Object Construction

```gleam
// Parse CCL text into flat key-value entries
pub fn parse(text: String) -> Result(List(Entry), ParseError)

// Convert flat entries into nested CCL structure using fixpoint algorithm  
pub fn make_objects(entries: List(Entry)) -> CCL

// Create an empty CCL structure
pub fn empty_ccl() -> CCL
```

### Value Access

```gleam
// Get a single value using dot-separated path
pub fn get_value(ccl: CCL, path: String) -> Result(String, String)

// Get all values for a path (useful for list-style structures with empty keys)
pub fn get_values(ccl: CCL, path: String) -> List(String)

// Get nested CCL object at a specific path
pub fn get_nested(ccl: CCL, path: String) -> Result(CCL, String)

// Check if a path exists
pub fn has_key(ccl: CCL, path: String) -> Bool

// Get all keys at a specific path level
pub fn get_keys(ccl: CCL, path: String) -> List(String)
```

### Helper Functions

```gleam
// Get value using list of keys (building block for dot notation)
pub fn get_value_by_keys(ccl: CCL, keys: List(String)) -> Result(String, String)

// Create CCL with single key-value pair
pub fn single_key_val(key: String, value: String) -> CCL

// Merge two CCL structures recursively
pub fn merge_ccl(ccl1: CCL, ccl2: CCL) -> CCL

// Create CCL from list of CCL structures
pub fn ccl_from_list(ccls: List(CCL)) -> CCL
```

## Data Types

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

## Usage Examples

### Basic Usage

```gleam
let config = "
database =
  host = localhost
  port = 5432
"

case ccl_core.parse(config) {
  Ok(entries) -> {
    let ccl = ccl_core.make_objects(entries)
    ccl_core.get_value(ccl, "database.host")  // -> Ok("localhost")
  }
  Error(err) -> // Handle parse error
}
```

### List Values

CCL represents lists using empty keys:

```gleam
let config = "
ports =
  = 8000
  = 8001
  = 8002
"

case ccl_core.parse(config) {
  Ok(entries) -> {
    let ccl = ccl_core.make_objects(entries)
    let ports = ccl_core.get_values(ccl, "ports")  // -> ["8000", "8001", "8002"]
  }
  Error(err) -> // Handle parse error
}
```


## When to Use This Package

Use `ccl_core` for:
- Minimal dependencies (only `gleam_stdlib`)
- Library development or building custom abstractions
- Direct control over parsing internals

Use [`ccl`](https://hex.pm/packages/ccl) for:
- Application development with enhanced APIs
- Smart type detection and unified access
- Better error messages and debugging

## Documentation

- [CCL Specification](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html)
- [API Documentation](https://hexdocs.pm/ccl_core/)