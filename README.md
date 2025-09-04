# Categorical Configuration Language (CCL) – Gleam Implementation

[![Package Version](https://img.shields.io/hexpm/v/ccl)](https://hex.pm/packages/ccl)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl/)

A Gleam implementation of the Categorical Configuration Language (CCL), organized as a multi-package workspace.

## Package Organization

This project is organized as a multi-package workspace with the following packages:

### 📦 [ccl_core](packages/ccl_core/) 
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl_core/)

**Minimal CCL parsing and access library** - The foundational package containing core CCL parsing logic and basic object construction.

Minimal CCL parsing and object construction with zero external dependencies.

### 📦 [ccl](packages/ccl/)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl/)

**Full-featured CCL library with smart accessors and type detection** - The complete user-facing library built on ccl_core with enhanced usability features.

Enhanced CCL library with unified access API and smart type detection.

### 📦 [ccl_test_loader](packages/ccl_test_loader/)

**Test case loader for CCL from JSON files** - Utilities for loading and processing JSON-based test suites for cross-language CCL implementation testing.

Utilities for loading and processing JSON-based test suites for cross-language testing.

## What is CCL?

CCL is a minimal configuration format using key-value pairs with indentation-based nesting:

```
database =
  host = localhost
  port = 5432
server =
  ports =
    = 8000
    = 8001
```

For the full specification, see: https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html

## Usage

Parse CCL text and access nested values using dot notation:

### Quick Start

```gleam
import ccl

let config = "database.host = localhost\ndatabase.port = 5432"
case ccl.parse(config) {
  Ok(entries) -> {
    let objects = ccl.make_objects(entries)
    case ccl.get(objects, "database.host") {
      Ok(ccl.CclString(host)) -> io.println("Host: " <> host)
      _ -> io.println("Host not found") 
    }
  }
  Error(err) -> io.println("Parse error: " <> err.reason)
}
```

### Real-World Example

CCL handles duplicate keys by merging them into structured objects:

```gleam
import ccl

let ccl_text = "
database =
  host = localhost
database =
  port = 5432
server =
  ports =
    = 8000
    = 8001
"

case ccl.parse(ccl_text) {
  Ok(flat_entries) -> {
    let ccl_obj = ccl.make_objects(flat_entries)
    // database.host = "localhost", database.port = "5432"
    // server.ports = ["8000", "8001"]
  }
  Error(err) -> io.println("Parse error: " <> err.reason)
}
```

### Package Selection Guide

Choose the right package for your specific use case:

#### 🎯 **Use `ccl` if you need:**
- **Application development** - Building apps that consume CCL configuration
- **Type-safe parsing** - `get_int()`, `get_bool()`, `get_float()` with error handling
- **Smart accessors** - Unified `get()` API that handles strings, lists, and objects
- **Better error messages** - Actionable guidance instead of generic parsing errors
- **Enhanced list handling** - Flexible handling of both single values and lists

#### ⚡ **Use `ccl_core` if you need:**
- **Library development** - Building your own CCL abstractions or tools
- **Minimal dependencies** - Zero external dependencies beyond Gleam stdlib
- **Custom parsing logic** - Direct access to parsing internals and entry structures
- **Performance-critical applications** - Minimal overhead for basic parsing

#### 🧪 **Use `ccl_test_loader` if you need:**
- **Testing CCL implementations** - Cross-language compatibility testing
- **Development utilities** - JSON-based test suite loading
- **Implementation validation** - Ensuring compliance with CCL specification

**Quick Decision:** Use `ccl` for applications, `ccl_core` for libraries.

## Installation

```sh
gleam add ccl       # Full-featured library (recommended)
gleam add ccl_core  # Minimal core library
```

## Documentation

### 📖 Learning Guides
- **[Getting Started](docs/getting-started.md)** - Quick introduction and first examples
- **[Advanced Patterns](docs/advanced-patterns.md)** - Complex configurations and best practices  
- **[Gleam Features](docs/gleam-features.md)** - Type-safe parsing and advanced error handling
- **[Migration Guide](docs/migration-guide.md)** - Convert from JSON, YAML, TOML, environment variables

### 📚 Reference
- **[CCL Specification](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html)** - Official language reference
- **[Glossary](docs/glossary.md)** - Technical terms and concepts
- **[API Documentation](https://hexdocs.pm/ccl/)** - Full library API reference
- **[Core API Documentation](https://hexdocs.pm/ccl_core/)** - Minimal library API reference

