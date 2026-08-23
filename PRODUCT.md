# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Astro (Starlight). Deploy target: Netlify. No site scaffold exists yet; the repo currently holds only the Gleam packages and `README.md`.

## Users

Primary: Gleam developers who need to read and edit CCL configuration files from their own applications. They arrive evaluating whether `ccl` fits, then return for install steps, API usage, and option semantics.

Secondary (confirmed present, not the design target): the maintainer, who runs the conformance suite and TUI viewer in `packages/ccl_test_runner`.

## Product Purpose

`ccl` is a Gleam implementation of CCL, the Categorical Configuration Language (catconflang.com), for the Erlang and JavaScript targets. It parses CCL into an opaque `Document`, offers typed reads, writes edits back in place, and integrates with `gleam/dynamic/decode`. Success: a Gleam developer can install the package, parse a config, read typed values, edit a key, and get back source that still looks like what they wrote.

## Positioning

Round-trip, edit-in-place documents, modelled on [tomlet](https://github.com/tylerbutler/tomlet). A parsed `Document` retains the original source, key order, comments, and indentation. Unedited documents reproduce their text exactly; `set_*`, `remove`, `append_list_item`, and `insert_comment_before` rewrite only the affected entry and preserve surrounding structure. Edits that could not be read back as written are rejected with a typed `EditError` instead of silently mangled.

## Operating Context

- Package published to Hex; API reference generated on hexdocs. The site is a companion guide and entry point, not a replacement for hexdocs.
- Users compile Gleam to Erlang or JavaScript with `gleam >= 1.11.0`; `gleam_stdlib` is the only runtime dependency.
- Related packages in the monorepo: `ccl_codegen` (emits decoders from Gleam types) and `ccl_test_runner` (conformance runner, CLI, TUI).
- Conformance is measured against the official `ccl-test-data` JSON suite (v1.0.0 taxonomy); declared capabilities live in `ccl-config.yaml`.

## Capabilities and Constraints

- Public API is the single `ccl` module; everything under `ccl/` is internal and must not appear in docs as importable.
- Parsing: `parse`, `parse_bytes`, `parse_indented`, `parse_with(options)`.
- Typed access: `get_string/int/bool/float/list/values`, `get`, `as_*`, `value_get`, `keys`; list indexing via numeric path segments.
- Editing: `set_string/int/bool/float/list/object/value`, `append_list_item`, `remove`, `insert_comment_before`, `to_string`.
- Options (opaque, `default_options` + `with_*`): line endings, tabs, top-level indent baseline, delimiter choice, boolean strictness, list coercion, list order.
- Decoding: `decode`, `parse_dynamic`, `to_dynamic`, plus `int_decoder`, `bool_decoder`, `float_decoder` (stdlib decoders never match because every CCL leaf is text).
- Layers: `entries`/`print`, `to_value`, `to_model`, `to_canonical_string`, `line_column`.
- Errors are stable tagged unions (`ParseError`, `GetError`/`ExpectedType`, `EditError`, `DecodeError`); variant changes are breaking.
- Known gap: `indent_tabs` output is not implemented; five `canonical_format` reference tests fail pending an upstream test-data fix (ccl-test-data#162).
- Terminology: "entry", "Document", "Value" (`StringValue`/`ObjectValue`/`ListValue`), "Model", "canonical format", "capabilities"/"behaviors" (test taxonomy).
- Site URL: `https://gleam.catconflang.org`. The site links to Hexdocs for the full API reference.

## Brand Commitments

- Name: `ccl` (package), "CCL Gleam" (repo). No logo or wordmark exists.
- Independent identity: tomlet is an API analogy only, not a visual or voice reference.
- Voice as used in README and docs: direct, technical, example-led; ASD-STE100 simplified English is the house style for prose.
- License: MIT.

## Evidence on Hand

- `README.md`: working code examples for parse, typed access, editing, options, decoding, and layers.
- `CHANGELOG.md`, `.changes/`: release history.
- Conformance results are reproducible locally via `just run-tests` / `just stats`; no published pass-rate number exists yet and must be measured, not claimed.
- No testimonials, adopters, benchmarks, or usage numbers exist. Do not fabricate any.

## Product Principles

1. The example is the argument: every claim about the API is shown with runnable Gleam code.
2. Never promise more than the conformance suite proves; state known gaps plainly.
3. One public module; docs never teach internal paths.
4. Editing fidelity over convenience: preserve what the user wrote.
5. The site complements hexdocs; it does not duplicate the generated reference.
