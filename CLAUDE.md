## CCL Project Context

**For CCL language specification and theory, refer to the CCL Documentation:**
- [CCL Specification Summary](https://ccl.tylerbutler.com/specification-summary) - Comprehensive CCL language specification
- [Syntax Reference](https://ccl.tylerbutler.com/syntax-reference) - Quick CCL syntax guide
- [Parsing Algorithm](https://ccl.tylerbutler.com/parsing-algorithm) - Language-agnostic implementation guide
- [Mathematical Theory](https://ccl.tylerbutler.com/theory) - Category theory and algebraic foundations

**For official sources:**
- Original CCL blog post: https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html
- Reference OCaml implementation: https://github.com/chshersh/ccl

## Gleam Implementation Status

This section focuses ONLY on the Gleam implementation details. For CCL language information, see the CCL Documentation above.

### CCL Architecture (4-Level Implementation)

The Gleam implementation follows the 4-level CCL architecture:

### Level 1: Entry Parsing (Core)
**Gleam API**: `ccl.parse(text) → Result(List(ccl.Entry), ccl.ParseError)`
- **Status**: ✅ FULLY IMPLEMENTED
- **Package**: `ccl_core` and `ccl`
- **Tests**: `ccl-test-suite/ccl-entry-parsing.json` (18 tests)

### Level 2: Entry Processing (Extensions)  
**Gleam API**: Comment filtering, composition functions
- **Status**: ✅ FULLY IMPLEMENTED (comments), ❌ NOT IMPLEMENTED (decorative sections)
- **Package**: `ccl`
- **Tests**: `ccl-test-suite/ccl-entry-processing.json` (10 tests)

### Level 3: Object Construction (Hierarchical)
**Gleam API**: `ccl.make_objects(entries) → ccl.CCL`
- **Status**: ✅ FULLY IMPLEMENTED
- **Package**: `ccl`
- **Tests**: `ccl-test-suite/ccl-object-construction.json` (8 tests)

### Level 4: Typed Parsing (Gleam-Specific)
**Gleam API**: `ccl.get_int()`, `ccl.get_bool()`, `ccl.get_string()`, etc.
- **Status**: ✅ FULLY IMPLEMENTED  
- **Package**: `ccl`
- **Tests**: `ccl-test-suite/ccl-typed-parsing-examples.json` (12 tests)

### Error Handling (All Levels)
**Status**: ✅ FULLY IMPLEMENTED
**Tests**: `ccl-test-suite/ccl-errors.json` (5 tests)

### ✅ FULLY IMPLEMENTED 
- **Pretty Printer** - Canonical CCL output formatting with comprehensive test coverage

### ❌ REMAINING WORK
- **Decorative Section Headers** (Level 2) - `group_by_sections()` API

## Gleam Package Structure

### Multi-package workspace with 3 packages:
- `packages/ccl_core/` - Minimal CCL parsing (zero dependencies)
- `packages/ccl/` - Full-featured library with typed parsing and utilities  
- `packages/ccl_test_loader/` - JSON test suite utilities

### Dependencies
- gleam_stdlib
- simplifile  
- gleam_json
- gleeunit (testing)

### Target Platform
- Erlang VM (BEAM) for production deployment

## Gleam Development Workflow

### Tool Management (Recommended)
```bash
# Use mise for version management
mise install  # Installs correct Gleam, Erlang, and Just versions

# Use just for common tasks
just test     # Run all tests
just build    # Build project
just format   # Format code
just check    # Type check
just all      # Run all checks
```

### Manual Commands
```bash
gleam test    # Run all tests
gleam build   # Compile project
gleam format  # Format code
gleam check   # Type check without building
```

### Code Conventions
- Use functional programming patterns with immutable data
- Leverage pattern matching exhaustively
- Prefer Result types over exceptions for error handling
- Use snake_case for functions and variables
- Type annotations optional but recommended for public APIs
- Follow Gleam's built-in formatter output

### Testing Strategy
- Use gleeunit for unit testing
- Test both happy path and error cases
- Test type safety and pattern matching exhaustiveness
- Focus on CCL parsing edge cases and object construction
- Verify BEAM VM concurrency patterns where applicable

### LSP Integration
- Gleam LSP included with `gleam` binary
- Automatic compilation and error reporting
- Type inference and hover documentation
- Format-on-save enabled by default

## Test Suite Architecture (Gleam Implementation)

### Multi-Level Test Organization
Tests are organized by CCL architecture level:

- **`ccl-entry-parsing.json`** (Level 1) - Core parsing (18 tests)
- **`ccl-entry-processing.json`** (Level 2) - Comments, composition (10 tests)  
- **`ccl-object-construction.json`** (Level 3) - Nested objects (8 tests)
- **`ccl-typed-parsing-examples.json`** (Level 4) - Type-aware parsing (12 tests)
- **`ccl-errors.json`** - Error handling (5 tests)
- **`ccl-pretty-printer.json`** - Pretty printing (15 tests)

### Gleam Test Implementation
- Tests loaded via `test/test_suite_types.gleam`
- Executed by `test/ccl_gleam_test.gleam`  
- All test cases in JSON format for cross-language compatibility
- Each test includes `meta` field with `level` and `tags`

### Pretty Printer Test Suite
**Properties**: 
- `round_trip` - Ensures parse(pretty_print(parse(input))) == parse(input)
- `canonical_format` - Verifies consistent formatting output
- `deterministic` - Tests that identical inputs produce identical outputs

## Tree-sitter CCL Parser Status

### ✅ FULLY IMPLEMENTED AND WORKING
- External C++ Scanner with INDENT/DEDENT token generation
- Comment parsing (single-line and multiline)
- Basic CCL parsing (keys, values, assignments, multiline keys)
- List syntax (bare lists and nested lists)
- Complex nesting with proper DEDENT generation
- Syntax highlighting via `show_highlight.js`
- Comprehensive testing
- No infinite loops, proper EOF handling

### ⚠️ Known Limitations
1. **Nested CCL Structure Granularity** - Content within nested sections parsed as plain text (cosmetic only)
2. **Multiline Comments at EOF** - Edge case parsing errors (minimal impact)

### Production Ready For:
- ✅ Editor syntax highlighting and navigation
- ✅ Language server integration  
- ✅ Build tools and CCL processing
- ✅ Developer tooling and IDE support
- ✅ All core CCL language features