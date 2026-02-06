# Unified Expected Output Rendering

**Date:** 2026-02-05
**Status:** Ready for implementation

## Problem

The test runner and TUI both render expected output, but with:
- Inconsistent formatting
- Duplicate code
- No shared styling

Changes require updating both places independently.

## Goals

1. Unify rendering logic for expected output
2. Single source of truth for styling (theme)
3. Input CCL and ExpectedEntries rendered distinctly
4. Whitespace visualization for raw CCL input

## Design

### Module Structure

```
src/render/
├── theme.gleam           # Color/style definitions
├── whitespace.gleam      # Whitespace visualization
├── entries.gleam         # ExpectedEntries renderer
└── ccl_input.gleam       # Raw CCL input renderer
```

### Theme

```gleam
// src/render/theme.gleam

import gleam/option.{type Option}
import shore/style

pub type Theme {
  Theme(
    key: style.Color,
    value: style.Color,
    separator: style.Color,
    whitespace: style.Color,
    punctuation: Option(style.Color),  // None = default
  )
}

pub fn default() -> Theme {
  Theme(
    key: style.Cyan,
    value: style.White,
    separator: style.Blue,
    whitespace: style.White,  // Note: dim not available, use white for now
    punctuation: option.None,
  )
}
```

### Whitespace Visualization

```gleam
// src/render/whitespace.gleam

pub type WhitespacePart {
  Text(String)
  Space           // " " → "·"
  Tab             // "\t" → "→"
  Newline         // "\n" → "↵"
  CarriageReturn  // "\r" → "␍"
}

/// Convert a string into parts with whitespace identified
pub fn visualize(input: String) -> List(WhitespacePart)

/// Convert parts back to display string with glyphs
pub fn to_display_string(parts: List(WhitespacePart)) -> String
```

### ExpectedEntries Renderer

Renders parsed key/value pairs as tuples: `(key, value)`

```gleam
// src/render/entries.gleam

import test_types.{type TestEntry}

pub type EntryPart {
  OpenParen
  Key(String)
  Comma
  Value(String)
  CloseParen
  Newline
}

/// Convert entries to renderable parts
pub fn to_parts(entries: List(TestEntry)) -> List(EntryPart)

/// Render to plain string (test runner)
pub fn to_string(entries: List(TestEntry)) -> String

/// Render to ANSI colored string (test runner with color)
pub fn to_ansi(entries: List(TestEntry), theme: Theme) -> String

/// Render to shore nodes (TUI)
pub fn to_shore(entries: List(TestEntry), theme: Theme) -> shore.Node(a)
```

**Output format:**
```
(foo, bar)
(baz, qux)
```

**Colors:**
- `(`, `,`, `)` → default (no color)
- key → cyan
- value → white

### CCL Input Renderer

Renders raw CCL with visible whitespace and syntax highlighting.

```gleam
// src/render/ccl_input.gleam

pub type CclPart {
  Key(String)
  Separator        // "="
  Value(String)
  Whitespace(WhitespacePart)
  Newline
}

/// Parse CCL input into renderable parts
pub fn to_parts(input: String) -> List(CclPart)

/// Render to plain string
pub fn to_string(input: String) -> String

/// Render to ANSI colored string with visible whitespace
pub fn to_ansi(input: String, theme: Theme) -> String

/// Render to shore nodes (TUI)
pub fn to_shore(input: String, theme: Theme) -> shore.Node(a)
```

**Output format:**
```
foo·=·bar↵
```

**Colors:**
- key → cyan
- `=` → blue
- value → white
- whitespace glyphs (`·`, `↵`, `→`) → dim gray (white for now until shore supports dim)

## Test Detail View Layout

```
INPUT (CCL):
────────────
foo·=·bar↵
baz·=·qux↵

EXPECTED:
────────────
(foo, bar)
(baz, qux)
```

Input appears above expected entries.

## Integration Points

### Test Runner (`test_runner.gleam`)

Replace inline formatting in error messages:
- `format_entries()` → `render/entries.to_string()` or `to_ansi()`

### TUI (`tui/views/test_detail.gleam`)

Replace `render_inputs()` and `render_expected()`:
- Input section → `render/ccl_input.to_shore()`
- ExpectedEntries → `render/entries.to_shore()`

## Future Enhancements

1. **Bold/italic support** - Extend shore to expose text attributes
2. **Configurable themes** - Load from config file
3. **Other Expected types** - Apply same pattern to ExpectedObject, ExpectedValue, etc.
4. **Treesitter integration** - Use actual CCL grammar for input parsing

## Implementation Order

1. Create `src/render/theme.gleam`
2. Create `src/render/whitespace.gleam` with tests
3. Create `src/render/entries.gleam` with tests
4. Create `src/render/ccl_input.gleam` with tests
5. Integrate into test runner
6. Integrate into TUI
7. Verify both render consistently
