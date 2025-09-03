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

// Parse CCL text demonstrating duplicate key handling
let ccl_text = "
// Duplicate keys merge at object level
database =
  host = localhost
database =
  port = 5432
  
// Empty keys accumulate into lists  
server =
  ports =
    = 8000
    = 8001
    = 8002
"

case ccl.parse(ccl_text) {
  Ok(flat_entries) -> {
    // Flat level: preserves duplicates as separate entries
    // [Entry("database", "host = localhost"), Entry("database", "port = 5432")]
    
    let ccl_obj = ccl.make_objects(flat_entries)
    // Object level: merges duplicate keys into single structure
    // database: { host: "localhost", port: "5432" }
    // server: { ports: { "": ["8000", "8001", "8002"] } }
    
    // Access merged object fields
    case ccl.get(ccl_obj, "database.host") {
      Ok(ccl.CclString(host)) -> io.println("Host: " <> host)  // "localhost"
      _ -> io.println("Host not found")
    }
    
    case ccl.get(ccl_obj, "database.port") {
      Ok(ccl.CclString(port)) -> io.println("Port: " <> port)  // "5432"  
      _ -> io.println("Port not found")
    }
    
    // Access list from empty keys
    case ccl.get(ccl_obj, "server.ports") {
      Ok(ccl.CclList(ports)) -> {
        io.println("Ports: " <> string.join(ports, ", "))  // "8000, 8001, 8002"
      }
      _ -> io.println("Ports not found")
    }
  }
  Error(err) -> io.println("Parse error: " <> err.reason)
}
```

### Package Selection Guide

Choose the right package for your needs:

- **`ccl`** - Full-featured library with unified access API (recommended for most applications)
- **`ccl_core`** - Minimal library for basic parsing (libraries, minimal dependencies)
- **`ccl_test_loader`** - Testing utilities for cross-language compatibility (development only)

## Installation

```sh
gleam add ccl       # Full-featured library (recommended)
gleam add ccl_core  # Minimal core library
```

## Documentation

- **[CCL Specification](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html)** - Language reference
- **[API Documentation](https://hexdocs.pm/ccl/)** - Full library docs
- **[Core API Documentation](https://hexdocs.pm/ccl_core/)** - Minimal library docs

