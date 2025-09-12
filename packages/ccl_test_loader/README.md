# ccl_test_loader

[![Package Version](https://img.shields.io/hexpm/v/ccl_test_loader)](https://hex.pm/packages/ccl_test_loader)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl_test_loader/)

Utilities for loading JSON-based test suites and converting between CCL objects and JSON for cross-language compatibility testing.

## Installation

```sh
gleam add --dev ccl_test_loader
```

## Quick Start

```gleam
import ccl_core
import ccl_test_loader

// Convert CCL to JSON for testing
let entries = [ccl_core.Entry("name", "Alice"), ccl_core.Entry("age", "30")]
let ccl = ccl_core.build_hierarchy(entries)
let json_string = ccl_test_loader.ccl_to_json_string(ccl)
// Result: "{\"name\":\"Alice\",\"age\":\"30\"}"
```

## Core API

### Available Functions

- `ccl_to_json(ccl: CCL) -> Json` - Convert CCL to JSON value
- `ccl_to_json_string(ccl: CCL) -> String` - Convert CCL to JSON string
- `json_to_ccl(json: Json) -> Result(CCL, String)` - ⚠️ Not yet implemented
- `json_string_to_ccl(json_string: String) -> Result(CCL, String)` - ⚠️ Not yet implemented

## Test Suite Format

This package works with JSON test suites in `ccl-test-suite/ccl-test-suite.json` containing test cases with input CCL text and expected parsed output for cross-language compatibility testing.

## Usage Example

```gleam
import ccl_core
import ccl_test_loader

pub fn test_ccl_to_json() {
  let entries = [ccl_core.Entry("database", "postgres"), ccl_core.Entry("port", "5432")]
  let ccl = ccl_core.build_hierarchy(entries)
  let json_string = ccl_test_loader.ccl_to_json_string(ccl)
  // Use json_string for cross-language testing
}

## Use Cases

- Cross-language CCL implementation testing
- Converting CCL objects to JSON for external tools  
- Validating CCL parsers against common test suites

## Dependencies

- **gleam_stdlib** - Standard library
- **gleam_json** - JSON encoding/decoding  
- **ccl_core** - CCL parsing