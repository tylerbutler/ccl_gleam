# ccl_gleam - Gleam CCL Implementation & Test Runner

CCL (Categorical Configuration Language) implementation and test runner in Gleam, targeting the Erlang VM (BEAM).

## Build Commands

```bash
gleam build              # Compile project
gleam test               # Run unit tests
gleam check              # Type check without building
gleam format             # Format code
gleam run -- <args>      # Run test runner
```

## Just Commands

```bash
just deps                # Install dependencies
just build               # Build project
just test                # Run unit tests
just format              # Format code
just check               # Type check
just run <dir>           # Run test runner against directory
just run-tests           # Run against default test data
just ci                  # Full CI check (format, build, test)
```

## Project Structure

```
src/
├── ccl/                       # CCL library (the real implementation)
│   ├── types.gleam            # Entry, CCLValue (String|Object|List), CCL type alias
│   ├── parser.gleam           # parse() — indentation-aware, two-context parsing
│   ├── hierarchy.gleam        # build_hierarchy() — recursive fixed-point
│   ├── access.gleam           # get_string, get_int, get_bool, get_float, get_list
│   └── format.gleam           # print (structure-preserving), canonical_format
├── test_runner/               # Test runner (calls ccl/ directly)
│   ├── runner.gleam           # Test execution against ccl/ library
│   ├── loader.gleam           # JSON test suite loading
│   ├── filter.gleam           # Capability-based test filtering
│   └── types.gleam            # Test-specific types (TestCase, Expected, etc.)
├── cli/                       # CLI commands
│   ├── commands.gleam         # run/list/stats commands
│   └── flags.gleam            # CLI flag definitions
├── tui/                       # Interactive TUI viewer
│   ├── app.gleam              # Shore TUI application
│   ├── model.gleam            # TUI state model
│   ├── update.gleam           # TUI update logic
│   ├── view.gleam             # TUI view rendering
│   └── views/                 # Individual view components
└── ccl_test_runner.gleam      # CLI entry point
```

## CCL Library (`src/ccl/`)

The core CCL implementation follows the docs at ccl.tylerbutler.com:

### Core Functions (Required)
- **`parser.parse(text)`** — Indentation-aware entry parsing with `toplevel_indent_strip` behavior (N=0 at top level, N=first content line indent for nested)
- **`hierarchy.build_hierarchy(entries)`** — Recursive fixed-point: values containing `=` are re-parsed until no more structure remains

### Typed Access (Optional)
- **`access.get_string(ccl, path)`** — Navigate path, return string
- **`access.get_int(ccl, path)`** — Parse integer
- **`access.get_bool(ccl, path)`** — Parse boolean (`boolean_strict`: only true/false)
- **`access.get_float(ccl, path)`** — Parse float
- **`access.get_list(ccl, path)`** — Extract list (handles `{"": CclList}` pattern)

### Formatting (Optional)
- **`format.print(entries)`** — Structure-preserving: `print(parse(x)) == x` for standard inputs
- **`format.canonical_format(ccl)`** — Semantic-preserving normalized output

### Internal Representation
Uses tagged union per CCL docs recommendation for Gleam:
```gleam
pub type CCLValue {
  CclString(String)          // Terminal value (no = in content)
  CclObject(Dict(String, CCLValue))  // Nested structure
  CclList(List(CCLValue))    // List from empty-key entries
}
```

### Implemented Behaviors
- `toplevel_indent_strip` — Top-level baseline N=0
- `crlf_normalize_to_lf` — Normalize CRLF before parsing
- `tabs_as_whitespace` — Spaces and tabs count as whitespace
- `boolean_strict` — Only true/false (case-insensitive)
- `list_coercion_disabled` — get_list errors on non-lists
- `array_order_insertion` — Preserve insertion order
- `indent_spaces` — 2-space indentation in output

## Integration with ccl-test-data

```bash
# Run with full capabilities
gleam run -- run ./ccl-test-data/

# Run with specific functions only
gleam run -- run ./ccl-test-data/ --functions parse,print

# Launch interactive TUI viewer
gleam run -- view ./ccl-test-data/
```

## Dependencies

- `gleam_stdlib` - Standard library
- `gleam_json` - JSON parsing
- `simplifile` - File system operations
- `birch` - Structured logging
- `argv` - CLI argument parsing
- `glint` - CLI framework
- `shore` - TUI framework
- `gleeunit` - Testing framework (dev)

## Development Guidelines

- Use Result types for error handling, not exceptions
- Pattern match exhaustively
- Follow Gleam's built-in formatter output
- The test runner calls `ccl/` modules directly — no interface indirection
- When adding CCL features, update both `ccl/` library and `test_runner/runner.gleam`
