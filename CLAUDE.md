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

### ✅ FULLY IMPLEMENTED 
- **Pretty Printer** - Canonical CCL output formatting with comprehensive test coverage

### ❌ REMAINING WORK
- **Decorative Section Headers** (Level 2) - `group_by_sections()` API

## Tree-sitter CCL Parser Status

### ✅ FULLY IMPLEMENTED AND WORKING
- **External C++ Scanner**: Complete INDENT/DEDENT token generation with indentation stack
- **Comment Parsing**: Both single-line (`/= comment`) and multiline comments with indented continuation lines
- **Basic CCL Parsing**: Keys, values, assignments, multiline keys all working correctly
- **List Syntax**: Both bare lists (`= item`) and nested lists (`foo = \n  = item1\n  = item2`)
- **Complex Nesting**: Multiple indentation levels handled with proper DEDENT generation
- **Syntax Highlighting**: Full color-coded output via `show_highlight.js` script including multiline comments
- **Comprehensive Testing**: All test files parse successfully with proper syntax highlighting
- **No Infinite Loops**: Scanner properly handles EOF and complex indentation patterns

### ⚠️ Known Limitations

#### 1. Nested CCL Structure Granularity
**Issue**: Content within nested sections (like `host = localhost` inside `config =`) is parsed as plain text (`value_line`) rather than structured CCL entries.

**Impact**: Affects only the granularity of syntax highlighting within nested content. All functionality works correctly.

**Technical Cause**: Tree-sitter's conflict resolution between `nested_section` and `multiline_value` contexts makes precedence-based disambiguation challenging within nested contexts.

#### 2. Multiline Comments at End-of-File  
**Issue**: Multiline comments ending the file without trailing content may parse with errors in edge cases.

**Impact**: Minimal - most files have trailing newlines and content after comments.

**Technical Cause**: GLR parser lookahead limitations at EOF. See `DEV.md` for detailed explanation and workarounds.

### Recommendation
The current implementation is **production-ready** for:
- ✅ Editor syntax highlighting and navigation
- ✅ Language server integration  
- ✅ Build tools and CCL processing
- ✅ Developer tooling and IDE support
- ✅ All core CCL language features

The nested structure limitation is cosmetic and doesn't affect CCL functionality.

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

### Pretty Printer Test Suite
**File**: `ccl-test-suite/ccl-pretty-printer.json` (15 tests)
**Properties**: 
- `round_trip` - Ensures parse(pretty_print(parse(input))) == parse(input)
- `canonical_format` - Verifies consistent formatting output
- `deterministic` - Tests that identical inputs produce identical outputs
**Coverage**: Empty values, whitespace normalization, tab preservation, multiline values, nested structures, list formatting