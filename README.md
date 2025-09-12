# CCL Gleam Implementation

[![Package Version](https://img.shields.io/hexpm/v/ccl)](https://hex.pm/packages/ccl)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl/)

A Gleam implementation of the [Categorical Configuration Language (CCL)](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html).

## Installation

```sh
gleam add ccl       # Full-featured library (recommended)
gleam add ccl_core  # Minimal core library
```

## Quick Start

```gleam
import ccl

let config = "
database.host = localhost
database.port = 5432
server.debug = true
"

case ccl.parse(config) {
  Ok(entries) -> {
    let objects = ccl.build_hierarchy(entries)
    
    // Type-safe access
    let host = ccl.get_string(objects, "database.host") // Ok("localhost")
    let port = ccl.get_int(objects, "database.port")    // Ok(5432)  
    let debug = ccl.get_bool(objects, "server.debug")   // Ok(True)
  }
  Error(err) -> io.println("Parse error: " <> err.reason)
}
```

## Package Organization

This project provides three packages:

### 📦 [ccl](packages/ccl/)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl/)

**Full-featured CCL library** - Type-safe parsing, smart accessors, enhanced usability.

### 📦 [ccl_core](packages/ccl_core/) 
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl_core/)

**Minimal CCL parsing library** - Zero dependencies, core parsing only.

### 📦 [ccl_test_loader](packages/ccl_test_loader/)

**Test utilities** - JSON test suite loader for CCL conformance testing.

## Usage Examples

### Parsing Nested Configuration

```gleam
import ccl

let config = "
database =
  host = localhost
  port = 5432
server =
  ports =
    = 8000
    = 8001
"

case ccl.parse(config) {
  Ok(entries) -> {
    let objects = ccl.build_hierarchy(entries)
    // Access nested values
    let host = ccl.get(objects, "database.host")   // Ok(CclString("localhost"))
    let ports = ccl.get(objects, "server.ports")   // Ok(CclList(["8000", "8001"]))
  }
  Error(err) -> io.println("Parse error: " <> err.reason)
}
```

### Type-Safe Value Access

```gleam
import ccl

// Get typed values with automatic parsing
let config_obj = ccl.parse(config_text) |> result.map(ccl.build_hierarchy)

// Integer parsing
case ccl.get_int(config_obj, "server.port") {
  Ok(port) -> start_server(port)
  Error(_) -> start_server(8080)  // Default port
}

// Boolean parsing
case ccl.get_bool(config_obj, "debug.enabled") {
  Ok(True) -> enable_debug_mode()
  Ok(False) -> disable_debug_mode()
  Error(_) -> disable_debug_mode()  // Default to production
}

// String access
case ccl.get_string(config_obj, "app.name") {
  Ok(name) -> io.println("Starting " <> name)
  Error(_) -> io.println("Starting application")
}
```

## Package Selection Guide

- **Use `ccl`** for applications needing full CCL features
- **Use `ccl_core`** for libraries wanting minimal dependencies
- **Use `ccl_test_loader`** for testing CCL implementations

## Development

### Tool Setup (Recommended)

This project uses `mise` for version management and `just` for task running:

```bash
# Install mise (version manager)
# macOS
brew install mise

# Or use the installer
curl https://mise.run | sh

# Activate the project's tool versions
mise install

# This will install the correct versions of:
# - Gleam
# - Erlang/OTP
# - Just (task runner)
```

### Using Just

This project includes a `justfile` for common development tasks:

```bash
# List all available commands
just

# Run tests
just test

# Build the project
just build

# Format code
just format

# Type check
just check

# Run all checks (format, check, build, test)
just all

# Clean build artifacts
just clean
```

### Manual Commands

If you prefer not to use `just`, you can run the Gleam commands directly:

```bash
# Run tests
gleam test

# Build project
gleam build

# Format code
gleam format

# Type check
gleam check
```

### Installing Tools Individually

If you don't want to use `mise`, you can install tools separately:

```bash
# Install Just
brew install just              # macOS
apt install just               # Ubuntu/Debian
cargo install just             # Via Rust

# Install Gleam
brew install gleam             # macOS
# Or see: https://gleam.run/getting-started/installing/
```

## Documentation

- **[Gleam API Guide](docs/gleam-api-guide.md)** - Complete API reference
- **[Gleam Patterns](docs/gleam-patterns.md)** - Advanced usage patterns
- **[Testing Guide](docs/TESTING.md)** - Running and adding tests
- **[Hex Documentation](https://hexdocs.pm/ccl/)** - Generated API docs

## CCL Language Resources

- **[CCL Specification](https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html)** - Official language specification
- **[OCaml Reference Implementation](https://github.com/chshersh/ccl)** - Original implementation