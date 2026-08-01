# Atto-backed `build_model` design

## Problem

`ccl/model.gleam` currently builds the canonical recursive `Model` with a small
hand-written recursive fold. Nested model values are detected by checking for a
leading newline and delegating back to `parser.parse_value_with`. The behavior is
correct for current tests, but the model path does not use a parser-combinator
library as desired.

## Proposed approach

Add `atto` as a dependency of the core `ccl` package and use it for the
model-building nested-value parsing path. This is a focused change: public
`build_model` and `build_model_with` signatures stay unchanged, top-level parsing
continues to use the existing `parser.parse` API, and the canonical `Model`
shape remains a recursive map where terminal values become keys pointing to an
empty model.

## Architecture

The model module should gain an internal Atto-backed helper that attempts to
parse raw entry values into nested `Entry` values. `build_model_with` continues
to fold over `Entry` values and merge duplicates recursively. The new helper is
only responsible for the model path's "is this value nested CCL or a terminal
leaf?" decision.

Atto is preferred over Nibble for this design because this change operates on
raw text values rather than a token stream. Nibble would be a better fit for a
larger lexer-plus-parser rewrite, which is outside this scope.

## Data flow

1. Callers parse top-level CCL into `List(Entry)` using the existing parser.
2. `build_model_with(entries, options)` folds entries into a `Dict(String,
   Model)`.
3. For each entry value, the Atto-backed helper attempts nested parsing when the
   value is structurally multiline.
4. If nested parsing returns entries, those entries are recursively passed to
   `build_model_with`.
5. Otherwise, the raw value is treated as a terminal leaf via
   `Model(dict.from_list([#(value, Model(dict.new()))]))`.

## Error handling

The public model-building API remains non-throwing and returns `Model`, not
`Result(Model, String)`. Values that do not parse as nested CCL remain terminal
leaves, preserving current behavior. Parse failures must not be silently treated
as successful nested structures; they either fall back to the terminal leaf path
or, if a stricter public API is added later, surface through that new API.

## Testing

Add focused tests for:

- terminal string values becoming singleton leaves
- multiline nested values becoming recursive models
- duplicate keys merging recursively
- malformed or non-nested multiline content falling back to terminal leaves

Then run the existing project checks to confirm the Atto-backed path preserves
current public behavior.

## Out of scope

- Replacing the top-level CCL parser with Atto
- Rewriting the parser around Nibble's lexer/token architecture
- Changing `build_model` or `build_model_with` public return types
- Changing canonical model semantics or duplicate merge behavior
