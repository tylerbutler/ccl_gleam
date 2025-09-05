## CCL Project Context
- Local reference copy of the CCL blog post is saved at plans/ccl_blog_reference.md - use this first for CCL documentation
- If local docs are insufficient, fall back to the authoritative CCL documentation at https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html
- The reference OCaml CCL implementation is at https://github.com/chshersh/ccl

## CCL Architecture (4-Level Implementation)

CCL is designed as a layered architecture where each level builds on the previous one:

### Level 1: Entry Parsing (Core)
**API**: `parse(text) → Result(List(Entry), ParseError)`
- Converts raw CCL text to flat key-value entries
- Handles whitespace, multiline values, unicode, error detection
- **Status**: ✅ FULLY IMPLEMENTED
- **Tests**: `ccl-test-suite/ccl-entry-parsing.json` (18 tests)

### Level 2: Entry Processing (Extensions)  
**API**: `filter_keys()`, composition functions
- Processes Entry[] to filtered/grouped Entry[]
- Comment filtering, duplicate key handling, algebraic composition
- **Status**: ✅ FULLY IMPLEMENTED (comments), ❌ NOT IMPLEMENTED (decorative sections)
- **Tests**: `ccl-test-suite/ccl-entry-processing.json` (10 tests)

### Level 3: Object Construction (Hierarchical)
**API**: `make_objects(entries) → CCL`
- Converts flat Entry[] to nested object structures
- Recursive parsing, duplicate key merging, empty key lists
- **Status**: ✅ FULLY IMPLEMENTED
- **Tests**: `ccl-test-suite/ccl-object-construction.json` (8 tests)

### Level 4: Typed Parsing (Language-Specific)
**API**: `get_int()`, `get_bool()`, `get_typed_value()`, etc.
- Type-aware extraction with validation and inference
- Smart parsing options, language-specific conveniences
- **Status**: ✅ FULLY IMPLEMENTED  
- **Tests**: `ccl-test-suite/ccl-typed-parsing-examples.json` (12 tests)

### Error Handling (All Levels)
**Tests**: `ccl-test-suite/ccl-errors.json` (5 tests)

### ❌ REMAINING WORK
- **Decorative Section Headers** (Level 2) - `group_by_sections()` API
- **Pretty Printer** - Canonical CCL output formatting

## Gleam Development Guidelines

### Project Structure
- **Multi-package workspace** with 3 packages:
  - `packages/ccl_core/` - Minimal CCL parsing (zero dependencies)
  - `packages/ccl/` - Full-featured library with typed parsing and utilities  
  - `packages/ccl_test_loader/` - JSON test suite utilities
- Tests in each package's `test/` directory using gleeunit framework
- Target: Erlang VM (BEAM) for production deployment
- Dependencies: gleam_stdlib, simplifile, gleam_json, cleam (dev)

### Build Commands
- `gleam check` - Type check without building
- `gleam build` - Compile project
- `gleam test` - Run all tests
- `gleam format` - Format code (runs automatically with LSP)
- `gleam run` - Run project entrypoint
- `gleam shell` - Start Erlang shell for REPL

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
=======
## Test Suite Architecture

### Multi-Level Test Organization
Tests are organized by CCL architecture level for clear implementation progression:

- **`ccl-entry-parsing.json`** (Level 1) - Core parsing conformance (18 tests)
- **`ccl-entry-processing.json`** (Level 2) - Comments, composition, filtering (10 tests)  
- **`ccl-object-construction.json`** (Level 3) - Nested object building (8 tests)
- **`ccl-typed-parsing-examples.json`** (Level 4) - Type-aware parsing (12 tests)
- **`ccl-errors.json`** - Error handling across all levels (5 tests)

### Legacy Files (Migration in Progress)
- **`ccl-test-suite.json`** - Original monolithic test suite (legacy, use new files)

### Test Implementation Guidelines
- All test cases MUST be in JSON format for language-agnostic testing
- Tests are loaded via `test/test_suite_types.gleam` and executed by `test/ccl_gleam_test.gleam`  
- NEVER add hardcoded test cases - always define in JSON
- Each test includes `meta` field with `level` and `tags` for categorization
- Implementers can choose which levels to support based on their needs