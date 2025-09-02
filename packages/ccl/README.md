# CCL – Full-Featured Categorical Configuration Language Library

[![Package Version](https://img.shields.io/hexpm/v/ccl)](https://hex.pm/packages/ccl)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl/)

Full-featured CCL library built on `ccl_core` with enhanced usability features and unified APIs.

## Installation

Add `ccl` to your Gleam project:

```sh
gleam add ccl
```

## Quick Start

```gleam
import ccl

let config = "
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

// Parse and build CCL object
let assert Ok(entries) = ccl.parse(config)
let ccl_obj = ccl.make_objects(entries)

// Use the unified get() API - automatically handles all data types
case ccl.get(ccl_obj, "database.host") {
  Ok(ccl.CclString(host)) -> io.println("Host: " <> host)
  _ -> io.println("Host not found")
}

case ccl.get(ccl_obj, "server.ports") {
  Ok(ccl.CclList(ports)) -> {
    io.println("Ports: " <> string.join(ports, ", "))
  }
  _ -> io.println("Ports not found")  
}
```

## Key Features

### Key Features

- **Unified `get()` API** - Single function that returns values in their natural form
- **Smart type detection** - Automatically handles strings, lists, and nested objects
- **Enhanced list handling** - Works with both single values and multi-value lists
- **Better error messages** - Actionable guidance instead of generic errors

## API Overview

### Core Types

```gleam
/// Unified value type returned by get()
pub type CclValue {
  CclString(String)      // Single string value
  CclList(List(String))  // List of string values  
  CclObject(CCL)         // Nested CCL object
}

/// Node types for structure inspection
pub type NodeType {
  SingleValue     // Single terminal value
  ListValue       // Multiple values (list structure)  
  ObjectValue     // Nested object with key-value pairs
  Missing         // Path doesn't exist
}
```

### Primary API Functions

```gleam
// 🎯 Unified accessor (recommended for most use cases)
pub fn get(ccl: CCL, path: String) -> Result(CclValue, String)

// 🔍 Type detection and structure inspection
pub fn node_type(ccl: CCL, path: String) -> NodeType
pub fn get_all_paths(ccl: CCL) -> List(String)

// 📋 Smart accessors with enhanced error handling
pub fn get_smart_value(ccl: CCL, path: String) -> Result(String, String)
pub fn get_list(ccl: CCL, path: String) -> Result(List(String), String)
pub fn get_value_or_first(ccl: CCL, path: String) -> Result(String, String)

// 🛠️ Debugging utilities
pub fn pretty_print_ccl(ccl: CCL) -> String
```

## Usage Examples

### Unified Access Pattern

The new `get()` function is the recommended way to access CCL data:

```gleam
import ccl

// Single values
case ccl.get(ccl_obj, "database.host") {
  Ok(ccl.CclString(host)) -> setup_database(host)
  Ok(_) -> panic("Expected string, got different type")
  Error(msg) -> use_default_host()
}

// Lists  
case ccl.get(ccl_obj, "server.ports") {
  Ok(ccl.CclList(ports)) -> {
    list.each(ports, fn(port) { start_server(port) })
  }
  Ok(_) -> panic("Expected list, got different type")
  Error(msg) -> use_default_ports()
}

// Nested objects
case ccl.get(ccl_obj, "database") {
  Ok(ccl.CclObject(db_config)) -> configure_database(db_config)
  Ok(_) -> panic("Expected object, got different type")
  Error(msg) -> use_default_db_config()
}
```

### Common Usage Patterns

```gleam
// Handle flexible configurations (single or multiple values)
case ccl.get_list(ccl_obj, "notification.email") {
  Ok(emails) -> list.each(emails, send_notification)
  Error(_) -> use_default_email()
}

// Get primary value from flexible config
case ccl.get_value_or_first(ccl_obj, "database.host") {
  Ok(host) -> connect_to(host)
  Error(_) -> connect_to("localhost")
}
```

### Type-Safe Configuration Loading

```gleam
pub type DatabaseConfig {
  DatabaseConfig(
    host: String,
    port: Int, 
    username: String,
    password: String
  )
}

pub fn load_database_config(ccl_obj: ccl.CCL) -> Result(DatabaseConfig, String) {
  use host <- result.try(case ccl.get(ccl_obj, "database.host") {
    Ok(ccl.CclString(h)) -> Ok(h)
    Ok(_) -> Error("database.host must be a string")
    Error(e) -> Error(e)
  })
  
  use port_str <- result.try(case ccl.get(ccl_obj, "database.port") {
    Ok(ccl.CclString(p)) -> Ok(p)
    Ok(_) -> Error("database.port must be a string") 
    Error(e) -> Error(e)
  })
  
  use port <- result.try(case int.parse(port_str) {
    Ok(p) -> Ok(p)
    Error(_) -> Error("database.port must be a valid integer")
  })
  
  use username <- result.try(case ccl.get(ccl_obj, "database.username") {
    Ok(ccl.CclString(u)) -> Ok(u)
    Ok(_) -> Error("database.username must be a string")
    Error(e) -> Error(e)
  })
  
  use password <- result.try(case ccl.get(ccl_obj, "database.password") {
    Ok(ccl.CclString(p)) -> Ok(p)
    Ok(_) -> Error("database.password must be a string")
    Error(e) -> Error(e)
  })
  
  Ok(DatabaseConfig(host: host, port: port, username: username, password: password))
}
```

## When to Use This Package

Use `ccl` for:
- Application development consuming CCL configuration
- Enhanced usability with smart type detection
- Flexible configurations (single or multiple values)
- Better error messages and debugging

Use `ccl_core` instead for:
- Library development or building custom abstractions
- Minimal dependencies
- Direct access to parsing internals

## Migration from CCL Core

All `ccl_core` functions remain available, so migration is non-breaking:

1. Replace `ccl_core` with `ccl` in your `gleam.toml`
2. Update imports from `ccl_core` to `ccl`
3. Gradually adopt the new `get()` API for enhanced functionality

## Dependencies

- **gleam_stdlib** ≥ 0.44.0 - Gleam standard library
- **ccl_core** (included) - Core CCL parsing and construction engine

## Documentation

- **[CCL Specification](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html)** - The authoritative CCL language documentation
- **[CCL Reference Implementation](https://github.com/chshersh/ccl)** - Original OCaml implementation  
- **[API Documentation](https://hexdocs.pm/ccl/)** - Complete Gleam API reference
- **[CCL Core Documentation](https://hexdocs.pm/ccl_core/)** - Lower-level parsing API

## Contributing

This package is part of the [ccl_gleam workspace](https://github.com/username/ccl_gleam). See the main repository for contribution guidelines and development setup.

## License

Licensed under the same terms as the main ccl_gleam project.