# Decorative Section Headers - NOT YET IMPLEMENTED ⏳

## Overview

Support for organizing CCL entries using decorative section headers is **planned but not yet implemented**. This feature provides visual organization and programmatic grouping of configuration entries as a **Level 2.5 conceptual layer** between Entry Processing and Object Construction.

## Architectural Position

Decorative section headers introduce a **logical grouping layer** that sits between Level 2 (Entry Processing) and Level 3 (Object Construction):

```
Level 1: Entry Parsing     → Entry[]                    ✅ IMPLEMENTED
Level 2: Entry Processing  → Entry[] (filtered/combined) ✅ IMPLEMENTED  
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

### Minimal Core API
```gleam
pub type SectionGroup {
  SectionGroup(header: Option(String), entries: List(Entry))
}

// Only two core functions needed!
pub fn is_section_header(entry: Entry) -> Bool
pub fn group_by_sections(entries: List(Entry)) -> List(SectionGroup)
```

### Detection Logic
```gleam
// Simple detection: empty key + value starts with =
fn is_section_header(entry: Entry) -> Bool {
  entry.key == "" && string.starts_with(entry.value, "=")
}
```

**Important**: Content after the `=` signs is entirely user-defined. Colons (`:`) are a common convention for separating categories from descriptions, but are **not required** by the API. Any text content works:

```ccl
== Database Settings ==     ✅ Valid section header
== Production Database ==   ✅ Valid section header  
== db-config ==            ✅ Valid section header
== [ENV] Database ==       ✅ Valid section header
== Database: Production == ✅ Valid section header (colon is just text)
```

## User-Defined Helper Functions

Users can easily implement common operations using standard Gleam list functions:

### Strip Section Headers
```gleam
// Remove all section headers from entry list
fn strip_section_headers(entries: List(Entry)) -> List(Entry) {
  list.filter(entries, fn(entry) { !ccl.is_section_header(entry) })
}

// Usage
let clean_entries = entries |> strip_section_headers()
```

### Find Section by Name
```gleam
// Get entries from specific section by exact header match
fn get_section_entries(groups: List(SectionGroup), section_name: String) -> List(Entry) {
  groups
  |> list.find(fn(group) {
    case group.header {
      Some(header) -> header == section_name
      None -> False
    }
  })
  |> result.map(fn(group) { group.entries })
  |> result.unwrap([])
}

// Usage
let database_entries = sections |> get_section_entries("= Database Config =")
```

### Find Section by Category (Flexible Text Matching)
```gleam
// Find section by partial string match - works with any text format
fn find_section_by_category(groups: List(SectionGroup), category: String) -> List(Entry) {
  groups
  |> list.find(fn(group) {
    case group.header {
      Some(header) -> string.contains(header, category)
      None -> False
    }
  })
  |> result.map(fn(group) { group.entries })
  |> result.unwrap([])
}

// Usage - works with any header format
let db_entries = sections |> find_section_by_category("Database")  // matches "Database: Production", "Database Settings", etc.
let env_entries = sections |> find_section_by_category("Production")  // matches "Database: Production", "Production Config", etc.
```

### Section Header Normalization
```gleam
// Clean section names by removing equals and trimming
fn normalize_section_names(groups: List(SectionGroup)) -> List(SectionGroup) {
  groups
  |> list.map(fn(group) {
    case group.header {
      Some(raw_header) -> {
        let clean_name = raw_header
          |> string.trim()
          |> string.trim_start("=")
          |> string.trim_end("=") 
          |> string.trim()
        SectionGroup(header: Some(clean_name), entries: group.entries)
      }
      None -> group
    }
  })
}

// Usage
let clean_sections = sections |> normalize_section_names()
```

### Extract Category from Colon-Separated Headers (Optional Convention)
```gleam
// Parse "Database: Production Config" -> "Database" (user convention, not API requirement)
fn extract_section_categories(groups: List(SectionGroup)) -> List(SectionGroup) {
  groups
  |> list.map(fn(group) {
    case group.header {
      Some(raw_header) -> {
        let category = raw_header
          |> string.trim()
          |> string.trim_start("=")
          |> string.trim_end("=")
          |> string.trim()
          |> string.split_once(":")
          |> result.map(fn(pair) { string.trim(pair.0) })
          |> result.unwrap(raw_header)  // Falls back to original if no colon
        SectionGroup(header: Some(category), entries: group.entries)
      }
      None -> group
    }
  })
}

// Usage - only works if you use colon convention
let categorized_sections = sections |> extract_section_categories()
let db_entries = categorized_sections |> get_section_entries("Database")

// Alternative: direct text matching works with any format
let db_entries = sections |> find_section_by_category("Database")  // More flexible
```

### Multiple Sections with Same Category
```gleam
// Get all sections matching a category
fn get_all_sections_by_category(groups: List(SectionGroup), category: String) -> List(List(Entry)) {
  groups
  |> list.filter(fn(group) {
    case group.header {
      Some(header) -> string.contains(header, category)
      None -> False
    }
  })
  |> list.map(fn(group) { group.entries })
}

// Usage - handle multiple logging sections
let all_logging_entries = sections |> get_all_sections_by_category("Logging")
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
let entries = ccl_core.parse(content) |> result.unwrap([])
let groups = ccl.group_by_sections(entries)  // Automatic detection

// Work with specific section (user-defined helper)
let data_entries = groups |> get_section_entries("= Section: Data =")
```

### Hybrid Processing Approach (Recommended)
```gleam
// Process different sections independently
let sections = ccl.group_by_sections(entries)

// Extract and process database configuration (user-defined helper)
let database_ccl = sections
  |> find_section_by_category("Database")
  |> ccl_core.build_hierarchy()
  
// Extract and process server configuration  
let server_ccl = sections
  |> find_section_by_category("Server")
  |> ccl_core.build_hierarchy()

// Work with both configurations
use db_host <- result.try(ccl.get_value(database_ccl, "database.host"))
use server_port <- result.try(ccl.get_int(server_ccl, "server.port"))
// ... application logic
```

### Custom Processing Pipelines
```gleam
// Clean and normalize in one pipeline
fn process_config_sections(content: String) -> Result(Dict(String, CCL), String) {
  use entries <- result.try(ccl_core.parse(content))
  
  let processed_sections = entries
    |> ccl.group_by_sections()
    |> extract_section_categories()  // Custom normalization
    |> list.fold(dict.new(), fn(acc, section) {
      case section.header {
        Some(category) -> {
          let section_ccl = ccl_core.build_hierarchy(section.entries)
          dict.insert(acc, category, section_ccl)
        }
        None -> acc  // Skip headerless sections
      }
    })
  
  Ok(processed_sections)
}

// Usage
use config_map <- result.try(process_config_sections(content))
use database_ccl <- result.try(dict.get(config_map, "Database"))
use db_host <- result.try(ccl.get_value(database_ccl, "database.host"))
// ... use configuration
```

### Pipeline Integration
```gleam
// Option 1: Clean processing pipeline (ignore sections)
content
|> ccl_core.parse()
|> result.unwrap([])
|> strip_section_headers()              // User-defined helper
|> ccl_core.build_hierarchy()              // Convert to CCL

// Option 2: Section-aware processing
content
|> ccl_core.parse()
|> result.unwrap([])
|> ccl.group_by_sections()              // Group into sections
|> process_sections_independently()     // Custom section handling

// Option 3: Hybrid - process specific sections
content
|> ccl_core.parse()
|> result.unwrap([])
|> ccl.group_by_sections()
|> find_section_by_category("Production")     // User-defined helper
|> ccl_core.build_hierarchy()                    // Process normally
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

### Multiline Section Headers

Section headers can contain multiline content following CCL's continuation line rules:

```ccl
== Section Header =
  Properly indented continuation    ✅ Best practice
```

```ccl  
== Section Header =
Unindented continuation             ✅ Also valid per CCL spec
```

**CCL Specification**: Lines without `=` are treated as continuation lines regardless of indentation. Both examples above create valid section headers that will be detected by `is_section_header()`.

### Optional Visual Separation

Empty lines between sections are optional and don't affect parsing or section detection:

```ccl
== Database Configuration ==
host = localhost  
port = 5432

=== Cache Settings ===
redis_host = localhost
redis_port = 6379
```

Both with and without empty lines work identically.

## Integration Points

### With Existing CCL System
```gleam
// Combined with existing Level 2 features
content
|> ccl_core.parse()
|> result.unwrap([])
|> strip_section_headers()     // User-defined helper
|> ccl.filter(["/", "#"]) // Remove comments (existing API)
|> ccl_core.build_hierarchy()     // Convert to CCL structure
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
- Works with existing `filter()` for comment removal
- Integrates with pretty printer output
- Compatible with all 4 CCL levels
- Hybrid processing workflows
- Section-aware configuration management

### Performance Tests
- Large files with many sections
- Deep nesting combined with sections
- Memory usage with section grouping