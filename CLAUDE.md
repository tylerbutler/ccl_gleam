## CCL Project Context
- Local reference copy of the CCL blog post is saved at plans/ccl_blog_reference.md - use this first for CCL documentation
- If local docs are insufficient, fall back to the authoritative CCL documentation at https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html
- The reference OCaml CCL implementation is at https://github.com/chshersh/ccl

## Implementation Status (Updated 2025-01-09)

### ✅ FULLY IMPLEMENTED
- **Nested Section Syntax** - Indented hierarchical config parsing with comprehensive test coverage
  - Documentation: plans/nested_section_syntax_plan.md ✅
  - API: `parse()` and `make_objects()` handle nested sections automatically
  - Tests: `nested_key_value_pairs`, `deep_nested_structure`, `recursive_nested_*`, `stress_test_complex_nesting`

- **Comment Layer** - Key-based filtering with simple `filter_keys()` function  
  - Documentation: plans/comment_layer_plan.md ✅
  - API: `filter_keys(entries, exclude_keys)` in packages/ccl/src/ccl.gleam
  - Tests: `comment_extension`, `comment_syntax_slash_equals`, `comment_preservation_composition`

- **Typed Parsing** - Type-safe parsing with Result types and smart inference
  - Documentation: plans/typed_parsing_plan.md ✅  
  - API: `get_int()`, `get_float()`, `get_bool()`, `get_typed_value()`, `smart_options()`
  - Tests: Full typed parsing test suite in ccl-test-suite/ccl-typed-parsing-examples.json

### ❌ NOT IMPLEMENTED
- **Decorative Section Headers** - Visual config organization with grouping APIs
  - Documentation: plans/decorative_section_headers_plan.md ⏳
  - Status: Only basic parsing test (`section_style_syntax`), no `SectionGroup` or `group_by_sections()` APIs

### ⚠️ PARTIALLY IMPLEMENTED  
- **Pretty Printer** - Debug output exists, canonical CCL formatting needed
  - Documentation: plans/pretty_printer_implementation_plan.md ⚠️
  - Current: `pretty_print_ccl()` outputs JSON-like debug format
  - Missing: Canonical CCL output for round-trip testing

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
## Test Suite
- All test cases are in JSON format in `ccl-test-suite/ccl-test-suite.json` for language-agnostic testing
- Test suite includes 57 regular test cases, 5 error test cases, and 10 nested test cases
- Tests are loaded via `test/test_suite_types.gleam` and executed by `test/ccl_gleam_test.gleam`
- Demo files are located in `test/demo_*.gleam` (moved from src directory)
- Future test specification is in `test/ccl_nested_test.gleam` (defines target behavior for unimplemented features)
- remember tests should awlays be innjson format and dynamically run!
- Never add hardcoded test cases! Always define the test cases in JSON.