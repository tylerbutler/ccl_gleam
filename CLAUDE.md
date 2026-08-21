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
gleam.toml                         # CCL library package at repo root (gleam_stdlib only)
src/ccl.gleam                      # THE public API — everything below is internal
src/ccl/                           # internal_modules in gleam.toml; not importable externally
├── types.gleam                    # Entry, CCLValue (String|Object|List), CCL type alias, Model
├── parser.gleam                   # parse(), parse_indented() — indentation-aware
├── hierarchy.gleam                # build_hierarchy() — Dict-based JSON-friendly projection
├── model.gleam                    # build_model() — OCaml-canonical recursive map
└── format.gleam                   # print (structure-preserving), canonical_format

packages/
├── ccl_codegen/                   # Decoder codegen CLI (depends on nothing but stdlib)
│   └── src/ccl_codegen/gen.gleam  # Gleam type parsing + decoder emission
└── ccl_test_runner/               # Test runner package (depends on ccl via path)
    ├── gleam.toml
    ├── ccl-test-data/             # JSON test suite data (downloaded, not committed)
    ├── src/
    │   ├── ccl_test_runner.gleam  # CLI entry point
    │   ├── test_runner/           # Test execution infrastructure
    │   │   ├── runner.gleam       # Test execution against ccl/ library
    │   │   ├── loader.gleam       # JSON test suite loading + file metadata helpers
    │   │   ├── filter.gleam       # Capability-based test filtering
    │   │   ├── config.gleam       # ccl-config.yaml loading
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

## Public API (`src/ccl.gleam`)

`ccl` is the entire public API, modelled on [tomlet](https://github.com/tylerbutler/tomlet).
Everything under `ccl/` is listed in `internal_modules`, so it is hidden from the
generated docs and cannot be imported from another package. Adding a public
function means adding it to `src/ccl.gleam`, not un-sealing an internal module.

Key shapes:

- **`Document`** — opaque; carries the parsed entries, the `Options` it was
  parsed with, the original source, and whether the source ended in a newline.
  Every edit clears the cached source through `edited/2` so `to_string`
  re-emits.
- **`Options`** — opaque; folds `ParseOptions` + `AccessOptions` +
  `BuildOptions` into one value behind `default_options()` and `with_*`
  builders.
- **`Value`** — public tagged union (`StringValue`/`ObjectValue`/`ListValue`).
  `ObjectValue` uses an **ordered assoc list**, not a `Dict`, so source order
  survives. `ccl.gleam` therefore has its own order-preserving builder
  (`build_pairs`) mirroring `hierarchy.gleam`'s merge semantics; the two must
  stay in step.
- **Errors** — `ParseError`, `GetError`/`ExpectedType`, `EditError`,
  `DecodeError`. All documented as stable: adding, removing, or renaming a
  variant is a breaking change.
- **Edit layer** — recursive over the flat `Entry` list. A nested entry's raw
  value carries the *absolute* indentation of its own deeper lines, so an edit
  re-detects the child baseline via `nested_indent` and only prefixes the level
  it is rewriting.

Note that `ccl.print` writes a comment entry as `/= text` where
`format.print` writes `/ = text`. Both re-parse identically; the facade's form
is the spelling CCL sources actually use.

## CCL internals (`src/ccl/`)

The core CCL implementation follows the docs at catconflang.com:

### Core Functions (Required)
- **`parser.parse(text)`** — Top-level entry parsing, baseline N=0 (`toplevel_indent_strip` feature)
- **`parser.parse_indented(text)`** — Indented entry parsing, baseline detected from first content line (required by `build_hierarchy` in ccl-test-data v1.0.0)
- **`hierarchy.build_hierarchy(entries)`** — JSON-friendly projection: nested objects, lists for repeated empty keys, strings at leaves
- **`model.build_model(entries)`** — Canonical recursive map mirroring OCaml's `Fix of t KeyMap.t`. Terminal strings become keys pointing to `Model(empty)`; duplicates merge; order-agnostic (ordering belongs to typed projections). See ccl-test-data#142.

### Typed Access (Optional)
Typed reads live on the public module only — `ccl.get_string`, `ccl.get_int`,
`ccl.get_bool`, `ccl.get_float`, `ccl.get_list`, `ccl.get_values` — walking the
ordered `Value` tree rather than a `Dict`. There is no internal access module.

### Dynamic decoding
`ccl.decode`/`ccl.parse_dynamic` feed `gleam/dynamic/decode`. Because every CCL
terminal value is text, stdlib's `decode.int`/`decode.bool`/`decode.float` never
match; `ccl.int_decoder()`, `ccl.bool_decoder()`, and `ccl.float_decoder()`
decode the lexical form instead, mirroring tomlet's `date_decoder()` pattern.
`ccl_codegen` emits these, so its output must stay in step with them.

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
- Output indent: `indent_spaces` only — `indent_tabs` is not implemented
  (`format.print`/`canonical_format` always emit space indentation) and is
  deliberately left undeclared so tests requiring it are skipped rather than
  run-and-failed
- Also supports: `multiline_values`, `path_traversal`

**Known gaps** (declared as supported; these specific test cases still fail):
- `canonical_format`: 5 `*_ocaml_reference`/`*_reference_behavior` tests in
  `api_reference_compliant.json` expect every terminal value wrapped as its
  own nested `key =\n` line (e.g. `unicode = 你好世界` →
  `unicode =\n  你好世界 =\n`), matching the `Ccl.Model.pretty` bug tracked
  upstream in [ccl-test-data#152](https://github.com/CatConfLang/ccl-test-data/issues/152)
  rather than the leaf-inlining `key = value` form the other 8
  `canonical_format` tests (including `toplevel_indent_strip`/
  `toplevel_indent_preserve` and `continuation_tab_to_space`) and `print`
  correctly use. Filed as
  [ccl-test-data#162](https://github.com/CatConfLang/ccl-test-data/issues/162)
  — we match the documented-correct (inline) convention and leave these 5
  failing pending a test-data fix.

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
- The test runner drives the library through the public `ccl` module only, so
  the conformance suite exercises the published surface. It must not import
  `ccl/*` — `internal_modules` will reject it
- When adding CCL features, update the internal module, expose it on
  `src/ccl.gleam`, and update `test_runner/runner.gleam` if a validation needs it
- Both `gleam test` and `gleam run -- run` use the same runner; no duplication needed
