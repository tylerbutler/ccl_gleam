# Categorical Configuration Language (CCL) – Gleam Implementation

[![Package Version](https://img.shields.io/hexpm/v/ccl)](https://hex.pm/packages/ccl)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl/)

A Gleam implementation of the Categorical Configuration Language (CCL), organized as a multi-package workspace.

## Package Organization

This project is organized as a multi-package workspace:

### 📦 [ccl_core](packages/ccl_core/) 
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl_core/)

**Minimal CCL parsing library** - Zero dependencies, core parsing only.

### 📦 [ccl](packages/ccl/)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl/)

**Full-featured CCL library** - Type-safe parsing, smart accessors, enhanced usability.

### 📦 [ccl_test_loader](packages/ccl_test_loader/)

**Test utilities** - JSON test suite loader for cross-language testing.

## What is CCL?

CCL is a minimal configuration format using key-value pairs with indentation-based nesting:

```ccl
database =
  host = localhost
  port = 5432
server =
  ports =
    = 8000
    = 8001
```

**[📖 Full CCL specification →](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html)**

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

### Advanced Example

```gleam
import ccl

let config = "
database =
  host = localhost
database =
  port = 5432
server =
  ports =
    = 8000
    = 8001
"

case ccl.parse(config) {
  Ok(entries) -> {
    let objects = ccl.make_objects(entries)
    // Access: ccl.get(objects, "database.host") -> Ok(CclString("localhost"))
    // Lists: ccl.get(objects, "server.ports") -> Ok(CclList(["8000", "8001"]))
  }
  Error(err) -> io.println("Parse error: " <> err.reason)
}
```

### Package Selection Guide

**Quick Decision:** Use `ccl` for applications, `ccl_core` for libraries.

- **`ccl`** - Full-featured with type-safe parsing, smart accessors, enhanced error handling
- **`ccl_core`** - Minimal dependencies, direct parsing access, performance-focused
- **`ccl_test_loader`** - Cross-language testing utilities

## Installation

```sh
gleam add ccl       # Full-featured library (recommended)
gleam add ccl_core  # Minimal core library
```

## Documentation

### 📖 Learning Path
1. **[Getting Started](docs/getting-started.md)** - Basic syntax and first Gleam program
2. **[User Guide](docs/user-guide.md)** - Advanced patterns and type-safe Gleam features  
3. **[Migration Guide](docs/migration-guide.md)** - Convert from JSON/YAML/TOML/env

### 📚 Reference
- **[FAQ](docs/ccl_faq.md)** - Common questions and gotchas
- **[Glossary](docs/glossary.md)** - Technical terms
- **[API Documentation](https://hexdocs.pm/ccl/)** - Complete API reference

