## CCL Project Context
- Local reference copy of the CCL blog post is saved at docs/ccl_blog_reference.md - use this first for CCL documentation
- Typed parsing plan is documented at docs/typed_parsing_plan.md with full API design and edge case analysis
- Comment layer implementation plan is documented at docs/comment_layer_plan.md with simple key-based filtering approach
- Nested section syntax parser plan is documented at docs/nested_section_syntax_plan.md for indented hierarchical config parsing
- Decorative section headers plan is documented at docs/decorative_section_headers_plan.md for visual config organization
- If local docs are insufficient, fall back to the authoritative CCL documentation at https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html
- The reference OCaml CCL implementation is at https://github.com/chshersh/ccl

## Gleam Development Guidelines

### Project Structure
- Main CCL implementation in `src/ccl.gleam` with core parsing and object construction
- Tests in `test/` directory using gleeunit framework
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