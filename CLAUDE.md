# ccl_gleam - Gleam CCL Implementation & Test Runner

CCL (Categorical Configuration Language) implementation and test runner in Gleam, targeting the Erlang VM (BEAM).

This is a monorepo with two packages connected via path dependencies.

## Build Commands

```bash
# From repo root using just (recommended)
just build               # Build all packages
just test                # Run all tests
just check               # Type check all packages
just format              # Format all code

# Per-package (from within packages/ subdirectory)
cd packages/ccl && gleam build
cd packages/ccl_test_runner && gleam test
```

## Just Commands

```bash
just deps                # Install dependencies for all packages
just build               # Build all packages
just build-ccl           # Build CCL library only
just build-runner        # Build test runner only
just test                # Run all tests
just test-ccl            # Run CCL library tests only
just test-runner         # Run test runner tests only
just format              # Format all code
just check               # Type check all packages
just run <dir>           # Run CLI test runner against directory
just run-tests           # Run against default test data
just update-test-data    # Download latest test data from GitHub releases
just ci                  # Full CI check (format, build, test)
```

## Project Structure

```
# CCL library lives at the repo root (gleam.toml, src/ccl/*)
src/ccl/
├── types.gleam                    # Entry, CCLValue (String|Object|List), CCL type alias
├── parser.gleam                   # parse(), parse_indented() — indentation-aware
├── hierarchy.gleam                # build_hierarchy() — recursive fixed-point
├── access.gleam                   # get_string, get_int, get_bool, get_float, get_list
├── decode.gleam                   # Typed decoders with path tracking
└── format.gleam                   # print (structure-preserving), canonical_format

packages/
├── ccl_codegen/                   # Decoder codegen helper package
└── ccl_test_runner/               # Test runner package (depends on ccl via path)
    ├── gleam.toml
    ├── ccl-test-data/             # JSON test suite data (downloaded, not committed)
    ├── src/
    │   ├── ccl_test_runner.gleam  # CLI entry point
    │   ├── test_runner/           # Test execution infrastructure
    │   │   ├── runner.gleam       # Test execution against ccl/ library
    │   │   ├── loader.gleam       # JSON test suite loading
    │   │   ├── filter.gleam       # Capability-based test filtering
    │   │   └── types.gleam        # Test-specific types (TestCase, Expected, etc.)
    │   ├── cli/                   # CLI commands
    │   │   ├── commands.gleam     # run/list/stats commands
    │   │   └── flags.gleam        # CLI flag definitions
    │   └── tui/                   # Interactive TUI viewer
    │       ├── app.gleam          # Shore TUI application
    │       ├── model.gleam        # TUI state model
    │       ├── update.gleam       # TUI update logic
    │       ├── view.gleam         # TUI view rendering
    │       └── views/             # Individual view components
    └── test/
        ├── ccl_test_runner_test.gleam # Startest entry point + standalone unit tests
        └── ccl_json_suite_test.gleam  # Data-driven JSON suite via startest describe/it
```

## Testing

Two complementary test entry points share the same underlying runner infrastructure:

### `gleam test` — Startest integration (primary for development)

Runs all JSON test cases as individual startest tests with per-test pass/fail/skip
reporting. Powered by `test/ccl_json_suite_test.gleam` which loads JSON files,
maps each `TestCase` to `it()` or `xit()`, and delegates execution to the
existing `test_runner/runner.gleam`.

```bash
just test                                                                  # Run everything
cd packages/ccl_test_runner && gleam test -- --test-name-filter="basic"    # Filter by test name
cd packages/ccl_test_runner && gleam test -- --test-name-filter="hierarchy" # Run hierarchy tests only
```

### `gleam run -- run` — CLI test runner (for CI, TUI, stats)

The original CLI runner with birch logging, summary statistics, TUI viewer, and
configurable capability flags. Useful for CI pipelines, interactive exploration,
and detailed statistics.

```bash
just run-tests                                  # Run all tests
just run run ./ccl-test-data/ --functions parse,print  # Specific functions
just stats                                      # Test statistics
just list                                       # List test files
just view                                       # Interactive TUI
```

## CCL Library (`src/ccl/`)

The core CCL implementation follows the docs at ccl.tylerbutler.com:

### Core Functions (Required)
- **`parser.parse(text)`** — Top-level entry parsing, baseline N=0 (`toplevel_indent_strip` feature)
- **`parser.parse_indented(text)`** — Indented entry parsing, baseline detected from first content line (required by `build_hierarchy` in ccl-test-data v1.0.0)
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

### Implemented Capabilities (ccl-test-data v1.0.0 taxonomy)

Declared in `ccl-config.yaml`. Features are always-on capabilities; behaviors
are paired choices the runner derives from each test's tags.

**Features declared (capability reports; do not gate tests):**
- `toplevel_indent_strip` — top-level parse uses baseline N=0
- `multiline_continuation` — indented continuation lines accumulate into values
- `multiline_keys` — keys may span multiple lines before `=`
- `comments`, `empty_keys`, `unicode`, `whitespace`, `optional_typed_accessors`

**Behaviors (paired choices supported):**
- Line endings: `crlf_normalize_to_lf` / `crlf_preserve_literal`
- Boolean: `boolean_strict` / `boolean_lenient`
- Continuation tabs: `continuation_tab_to_space` (1:1 tab→space map) / `continuation_tab_preserve`
- List coercion: `list_coercion_disabled` / `list_coercion_enabled`
- Array order: `array_order_insertion` / `array_order_lexicographic`
- Delimiter: `delimiter_first_equals` / `delimiter_prefer_spaced`
- Output indent: `indent_spaces` / `indent_tabs`
- Also supports: `multiline_values`, `path_traversal`

**Known gaps:**
- Three `parse_indented` tests in `api_proposed_behavior.json` (and one
  dependent `build_hierarchy` test) fail due to OCaml-canonical semantics
  that Gleam's `parse_indented` doesn't yet mirror

## Dependencies

### CCL library (repo root)
- `gleam_stdlib` - Standard library

### Test runner (`packages/ccl_test_runner/`)
- `ccl` - CCL library (path dependency)
- `gleam_stdlib` - Standard library
- `gleam_json` - JSON parsing
- `simplifile` - File system operations
- `birch` - Structured logging
- `argv` - CLI argument parsing
- `glint` - CLI framework
- `shore` - TUI framework
- `startest` - Testing framework (dev) — describe/it API with test discovery

## Development Guidelines

- Use Result types for error handling, not exceptions
- Pattern match exhaustively
- Follow Gleam's built-in formatter output
- The test runner calls `ccl/` modules directly — no interface indirection
- When adding CCL features, update both `ccl/` library and `test_runner/runner.gleam`
- Both `gleam test` and `gleam run -- run` use the same runner; no duplication needed
