# CCL Gleam

A Gleam implementation of [CCL (Categorical Configuration Language)](https://catconflang.com/) with an integrated test runner for the [ccl-test-data](https://github.com/CatConfLang/ccl-test-data) JSON test suite.

CCL parses into an opaque `Document` that retains the original source, key order, comments, and indentation. Unedited documents round-trip to their original text; edits are written back in place while preserving the surrounding structure. The API follows [tomlet](https://github.com/tylerbutler/tomlet), which takes the same approach for TOML.

## Quick start

```gleam
import ccl

pub fn main() {
  let source = "/= the server block\nserver =\n  host = localhost\n  port = 8080\n"

  case ccl.parse(source) {
    Ok(doc) ->
      case ccl.set_int(doc, ["server", "port"], 9090) {
        Ok(updated) -> ccl.to_string(updated)
        // -> "/= the server block\nserver =\n  host = localhost\n  port = 9090\n"
        Error(error) -> handle_edit_error(error)
      }
    Error(error) -> handle_parse_error(error)
  }
}
```

The `handle_*` functions above stand in for your own error handling; each `case` surfaces the `ParseError`, `GetError`, or `EditError` that CCL returns instead of crashing.

## The public API

`ccl` is the entire public API. Everything under `ccl/` is an implementation detail — hidden from the docs and not importable from another package — so the internal representation can change without breaking callers.

### Parsing and typed access

Use `ccl.parse` for `String` input, `ccl.parse_bytes` when raw bytes need UTF-8 validation first, and `ccl.parse_indented` for a fragment that still has the enclosing block's indentation.

```gleam
let assert Ok(doc) = ccl.parse("server =\n  host = localhost\n  port = 8080\n")
let assert Ok("localhost") = ccl.get_string(doc, ["server", "host"])
let assert Ok(8080) = ccl.get_int(doc, ["server", "port"])
let assert Ok(["host", "port"]) = ccl.keys(doc, ["server"])
```

Typed accessors are `get_string`, `get_int`, `get_bool`, `get_float`, `get_list`, and `get_values`. Use `get` when you want to inspect a value through the public `ccl.Value` type, whose `ObjectValue` keeps its entries in source order. `as_string`, `as_int`, `as_bool`, `as_float`, `as_list`, and `as_pairs` do the same reads against a `Value` you already hold, and `value_get` walks further into one.

A path segment that is a non-negative decimal indexes into a list, so `["ports", "0"]` reads the first item of `ports =\n  = 80`.

Mismatches return `WrongType(path, expected)` with a stable `ExpectedType` variant; missing keys return `KeyNotFound(path)`.

### Editing

```gleam
let assert Ok(doc) = ccl.set_list(ccl.new(), ["ports"], ["80", "443"])
ccl.to_string(doc)
// -> "ports =\n  = 80\n  = 443\n"
```

`set_string`, `set_int`, `set_bool`, `set_float`, `set_list`, `set_object`, and `set_value` write at a key path, creating intermediate blocks as needed. An existing key is replaced in place, keeping its position and the comments around it, and nested edits reuse the indentation already in the document. `append_list_item`, `remove`, and `insert_comment_before` round out the edit surface.

Edits that could not be read back as written are rejected rather than silently mangled: `EmptyKeyPath`, `InvalidKeySegment`, `InvalidCommentText`, `MissingEditKey`, `KeyConflict`, and `InvalidValue`.

### Options

`Options` is opaque, so new settings can be added without breaking callers. Start from `default_options` and pipe through the `with_*` builders:

```gleam
let options =
  ccl.default_options()
  |> ccl.with_delimiter(ccl.FirstEquals)
  |> ccl.with_tabs(ccl.TabsAsContent)
  |> ccl.with_booleans(ccl.BooleanLenient)

ccl.parse_with(source, options)
```

The settings cover line endings (`NormalizeCrlf`/`PreserveCrlf`), tabs (`TabsAsWhitespace`/`TabsAsContent`), the top-level indentation baseline (`StripToplevelIndent`/`PreserveToplevelIndent`), delimiter choice (`PreferSpaced`/`FirstEquals`), boolean strictness (`BooleanStrict`/`BooleanLenient`), list coercion (`CoercionDisabled`/`CoercionEnabled`), and list order (`InsertionOrder`/`LexicographicOrder`). A document keeps the options it was parsed with, so reads stay consistent with the parse.

### Dynamic decoding

```gleam
import gleam/dynamic/decode

let server_decoder = {
  use host <- decode.field("host", decode.string)
  use port <- decode.field("port", decode.string)
  decode.success(#(host, port))
}

ccl.decode("host = localhost\nport = 8080\n", server_decoder)
// -> Ok(#("localhost", "8080"))
```

`parse_dynamic` and `to_dynamic` produce the same JSON-like shape without running a decoder.

Every CCL terminal value is text, so stdlib's `decode.int`, `decode.bool`, and `decode.float` never match a parsed document. Use `ccl.int_decoder()`, `ccl.bool_decoder()`, and `ccl.float_decoder()` for those fields — they decode the same lexical form the `get_int`/`get_bool`/`get_float` accessors accept:

```gleam
let server_decoder = {
  use host <- decode.field("host", decode.string)
  use port <- decode.field("port", ccl.int_decoder())
  use debug <- decode.field("debug", ccl.bool_decoder())
  decode.success(#(host, port, debug))
}
```

`ccl_codegen` generates decoders in exactly this form from a Gleam type definition.

### CCL's own layers

CCL is defined as a parse pass over flat entries, then projections over them, and the API exposes each layer:

- `entries` and `print` — the flat `key = value` pass. `print(entries(doc))` reproduces standard-format source.
- `to_value` — the JSON-friendly projection, in source order.
- `to_model` — the canonical recursive `Model`, mirroring the OCaml reference's `Fix of t KeyMap.t`.
- `to_string` — the document's original text, or a re-emission after an edit.
- `to_canonical_string` — normalised two-space indentation with keys sorted and duplicates merged.

`line_column` turns a `ParseError` byte offset into a one-based `Position` for diagnostics.

## Packages

This monorepo contains the library plus two supporting packages:

| Package | Path | Description |
|---------|------|-------------|
| **ccl** | repo root | Core CCL library — the public `ccl` module over internal parser, hierarchy, model, and formatter modules |
| **ccl_codegen** | `packages/ccl_codegen/` | Generates `gleam/dynamic/decode` decoders from Gleam type definitions |
| **ccl_test_runner** | `packages/ccl_test_runner/` | Test runner CLI, TUI viewer, and startest integration |

The test runner drives the library through the public `ccl` module, so the conformance suite exercises the same surface published to library users.

## Quick commands

```sh
just deps       # Install dependencies
just test       # Run all tests
just run-tests  # Run the CLI test runner
just view       # Launch the interactive TUI viewer
just ci         # Full CI check
```

## Development

See [DEV.md](DEV.md) for detailed development instructions.

## Test suite format

See the [CCL Test Suite Guide](https://catconflang.com/test-suite-guide/) for details on the JSON test format and expected results structure.
