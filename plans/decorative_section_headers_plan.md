# Decorative Section Headers - NOT YET IMPLEMENTED ⏳

## Overview

Support for organizing CCL entries using decorative section headers is **planned but not yet implemented**. This feature provides visual organization and programmatic grouping of configuration entries as a **Level 2.5 conceptual layer** between Entry Processing and Object Construction.

## Architectural Position

Decorative section headers introduce a **logical grouping layer** that sits between Level 2 (Entry Processing) and Level 3 (Object Construction):

```
Level 1: Entry Parsing     → Entry[]                    ✅ IMPLEMENTED
Level 2: Entry Processing  → Entry[] (filtered/composed) ✅ IMPLEMENTED  
Level 2.5: Section Grouping → SectionGroup[] (organized) ❌ NOT IMPLEMENTED
Level 3: Object Construction → CCL (nested objects)      ✅ IMPLEMENTED
Level 4: Typed Parsing     → typed values               ✅ IMPLEMENTED
```

### Key Insight

Section headers create **logical groupings** that are **orthogonal** to CCL's hierarchical nesting:
- **Section grouping**: Database vs Server sections (visual/organizational)
- **Object nesting**: `database.host`, `server.port` (structural hierarchy)

This enables both simple pipeline processing and powerful section-aware workflows.

## Decorative Section Header Syntax

### Section Header Definition (Simplified)

**A section header is any entry with an empty key whose value starts with `=`.**

```ccl
== Simple Header
=== Header Level 3 ===
==== Database Configuration ====
===== Nested Section =====
```

**CCL Parsing Behavior**: When CCL encounters a line starting with `=`, it treats the first `=` as the assignment operator:
- **key**: `""` (empty)
- **value**: everything after the first `=`

Examples:
- `== Section ==` → `Entry(key: "", value: "= Section ==")` ✅ **Section header**
- `=== Config ===` → `Entry(key: "", value: "== Config ===")` ✅ **Section header**  
- `= apple` → `Entry(key: "", value: "apple")` ❌ **List item** (not section)

### Design Benefits
- **Simple and general** - Any number of `=` signs supported
- **Visually clear** - More `=` signs indicate hierarchy/importance
- **Parser-friendly** - Uses existing CCL parsing rules
- **Flexible** - Users control their own decorative style

Headers can work with both flat and nested configurations:

### With Flat Configuration
```ccl
=== Section: Data ===
data.str = 1000
data.flags = 8

=== Section: Code ===  
code.step.0 = read
code.step.1 = eval
code.step.2 = print
code.step.3 = loop
```

### With Indented Nested Sections
```ccl
=== Section: Data ===
data =
  str = 1000
  flags = 8

=== Section: Code ===
code =
  steps =
    = read
    = eval
    = print
    = loop
```

## Design Philosophy

- **Visual organization** - Helps humans read and understand config files
- **Programmatic grouping** - Allows code to work with logical sections
- **No structural changes** - Headers are just regular entries that can be filtered
- **Flexible patterns** - Users choose their own header syntax

## Current Status

### Test Coverage
The test suite includes one basic test for section-like syntax:
- `section_style_syntax` - Tests `== Section 2 ==` parsing as empty key

### Implementation Status
- ❌ **SectionGroup** type not implemented
- ❌ **HeaderPattern** type not implemented  
- ❌ **group_by_sections()** function not implemented
- ❌ Section filtering and grouping APIs missing

### Simplified API Design
```gleam
pub type SectionGroup {
  SectionGroup(header: Option(String), entries: List(Entry))
}

// Core functions - no pattern types needed!
pub fn group_by_sections(entries: List(Entry)) -> List(SectionGroup)
pub fn strip_section_headers(entries: List(Entry)) -> List(Entry)  
pub fn is_section_header(entry: Entry) -> Bool
```

### Detection Logic
```gleam
// Simple detection: empty key + value starts with =
fn is_section_header(entry: Entry) -> Bool {
  entry.key == "" && string.starts_with(entry.value, "=")
}
```

### Grouping Functions
```gleam
// Group entries by section headers
pub fn group_by_sections(
  entries: List(Entry), 
  pattern: HeaderPattern
) -> List(SectionGroup) {
  // Returns sections with their associated entries
  // First group has header = None for entries before first section
}

// Extract entries from specific section
pub fn get_section_entries(
  groups: List(SectionGroup), 
  section_name: String
) -> List(Entry) {
  // Find section by header content and return its entries
}
```

### Filtering Functions
```gleam
// Remove section headers from entry list
pub fn strip_section_headers(
  entries: List(Entry), 
  pattern: HeaderPattern
) -> List(Entry) {
  // Filter out entries that match the header pattern
}

// Get only section headers
pub fn get_section_headers(
  entries: List(Entry), 
  pattern: HeaderPattern
) -> List(String) {
  // Extract just the header values
}
```

### Detection Functions
```gleam
// Check if an entry is a section header
pub fn is_section_header(entry: Entry, pattern: HeaderPattern) -> Bool

// Extract section name from header
pub fn extract_section_name(header: String, pattern: HeaderPattern) -> Option(String)
```

## Usage Examples

### Basic Grouping
```gleam
let entries = parse_ccl_string(content)
let groups = group_by_sections(entries)  // Automatic detection

// Work with specific section
let data_entries = get_section_entries(groups, "= Section: Data =")
```

### Hybrid Processing Approach (Recommended)
```gleam
// Process different sections independently
let sections = group_by_sections(entries)

// Extract and process database configuration
let database_ccl = sections
  |> get_section_entries("= Database Config =")
  |> ccl_core.make_objects()
  
// Extract and process server configuration  
let server_ccl = sections
  |> get_section_entries("= Server Config =")
  |> ccl_core.make_objects()

// Work with both configurations
use db_host <- result.try(ccl.get_value(database_ccl, "database.host"))
use server_port <- result.try(ccl.get_int(server_ccl, "server.port"))
// ... application logic
```

### Custom Header Patterns
```gleam
// INI-style headers: [Section]
let ini_pattern = PrefixSuffix("[", "]")

// Custom detection
let custom_pattern = Custom(fn(key) { 
  string.starts_with(key, "-- ") && string.ends_with(key, " --")
})
```

### Pipeline Integration
```gleam
// Option 1: Clean processing pipeline (ignore sections)
content
|> parse_ccl_string()
|> strip_section_headers()              // Remove visual headers
|> ccl_core.make_objects()              // Convert to CCL

// Option 2: Section-aware processing
content
|> parse_ccl_string() 
|> group_by_sections()                  // Group into sections
|> process_sections_independently()     // Custom section handling

// Option 3: Hybrid - process specific sections
content
|> parse_ccl_string()
|> group_by_sections()
|> get_section_entries("= Production Config =")  // Extract one section
|> ccl_core.make_objects()                       // Process normally
```

## Implementation Strategy

### Header Detection
1. **Pattern matching** - Use provided HeaderPattern to identify headers
2. **Flexible extraction** - Extract section names from header text
3. **Configurable** - Support multiple header styles in same file

### Grouping Algorithm
1. Iterate through entries in order
2. When header found, start new section group
3. Add subsequent entries to current section
4. Continue until next header or end of file

### Section Header Detection and Parsing

#### Detection Rules
1. **Check if keyless**: `entry.key == ""`
2. **Check starts with equals**: `string.starts_with(entry.value, "=")`
3. **Raw value**: Store entire `entry.value` as section name

#### Edge Cases and Spacing
```ccl
== Header ==        → Entry(key: "", value: "= Header ==")      ✅ Section header
=== Config          → Entry(key: "", value: "== Config")        ✅ Section header  
= = spaced          → Entry(key: "", value: " = spaced")        ❌ List item (space before =)
=  = wide           → Entry(key: "", value: " = wide")          ❌ List item (space before =)
= item              → Entry(key: "", value: "item")             ❌ List item (no leading =)
```

**Rule**: Equals signs must be **consecutive at the start** of the value (no spaces) to be detected as section headers.

## Integration Points

### With Existing CCL System
```gleam
// Combined with existing Level 2 features
content
|> parse_ccl_string()
|> strip_section_headers()     // Remove decorative headers  
|> filter_keys(["/", "#"])     // Remove comments (existing API)
|> ccl_core.make_objects()     // Convert to CCL structure
```

### With Nested Sections
```gleam
// Can be used together
content
|> parse_nested_sections()                     // Handle indented sections
|> group_by_sections(FixedPattern("==="))      // Group by decorative headers
```

## Benefits

1. **Visual clarity** - Config files easier to read and navigate
2. **Logical grouping** - Related settings grouped together
3. **Tool-friendly** - Enables section-aware config tools
4. **Non-invasive** - Doesn't change parsing or data structures
5. **Flexible** - Users control header syntax

## Common Header Patterns

### Section Headers with Nested Configuration
```ccl
== Database Configuration
database =
  host = localhost
  port = 5432
  name = myapp

=== Server Settings ===
server =
  host = 0.0.0.0
  port = 8080
  ssl =
    enabled = true
    cert = /path/to/cert.pem

==== Logging Options ====
logging =
  level = info
  file = /var/log/app.log
```

### Mixed Header Styles
```ccl
== Simple Header
database =
  host = localhost
  port = 5432

=== Double Equals Header ===
server =
  host = 0.0.0.0
  port = 8080

==== Triple Equals Header ====
logging =
  level = info
  file = /var/log/app.log

===== Quad Header for Nested Config =====
advanced =
  security =
    auth = enabled
    ssl = required
```

### Section Headers vs List Items
```ccl
== Database Config ==
database =
  primary =
    host = db1.example.com
    port = 5432
  replica =
    host = db2.example.com
    port = 5432

=== Server Config ===
server =
  host = 0.0.0.0
  port = 8080
  middleware =
    = cors
    = auth
    = logging

==== Logging Config ====
logging =
  level = info
  outputs =
    = console
    = file
```

**Note**: List items like `= cors` are **not** section headers because their values don't start with `=`.

### Hierarchical Headers with Flexible Trailing Equals
```ccl
== TOP LEVEL: Application Config

=== Database Settings ===
database =
  connection =
    host = localhost
    port = 5432
    pool_size = 20

=== Server Configuration
server =
  bind =
    host = 0.0.0.0
    port = 8080
  features =
    = ssl
    = compression
    = caching

==== Advanced Logging ====
logging =
  level = info
  destinations =
    file =
      path = /var/log/app.log
      rotate = true
    console =
      format = json

===== Debug Settings
debug =
  verbose = true
  trace = false
```

**Note**: Trailing `=` signs are **optional** - users can choose symmetric (`=== Section ===`) or minimal (`=== Section`) styling.

## Testing Requirements

### Core Functionality Tests
- Parse keyless values with varying `=` counts correctly
- Group entries under appropriate sections
- Handle entries before first section (orphaned entries)
- Extract section names accurately from equals patterns
- Filter headers while preserving other entries
- Support mixed header levels in same file (=, ==, ===, etc.)

### Edge Cases
- Empty sections (header with no following entries)
- Headers at end of file
- Multiple consecutive headers
- Headers mixed with comments and regular entries
- Very long header text
- Unicode content in headers
- Spaced equals like `= = foo` (treated as list items, not headers)
- Mixed spacing patterns within same file

### Integration Tests
- Works with existing `filter_keys()` for comment removal
- Integrates with pretty printer output
- Compatible with all 4 CCL levels
- Hybrid processing workflows
- Section-aware configuration management

### Performance Tests
- Large files with many sections
- Deep nesting combined with sections
- Memory usage with section grouping