# Decorative Section Headers - NOT YET IMPLEMENTED ⏳

## Overview

Support for organizing CCL entries using decorative section headers is **planned but not yet implemented**. This feature would provide visual organization and programmatic grouping of configuration entries.

## Decorative Section Header Syntax

Following the CCL specification, decorative headers use special key patterns. These can work with both flat and nested configurations:

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

### Proposed API Design
```gleam
pub type SectionGroup {
  SectionGroup(header: Option(String), entries: List(Entry))
}

pub type HeaderPattern {
  FixedPattern(String)           // "==="
  PrefixSuffix(String, String)   // "===" and "==="  
  RegexPattern(String)           // Custom regex
  Custom(fn(String) -> Bool)     // User-defined detector
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
let pattern = FixedPattern("===")
let groups = group_by_sections(entries, pattern)

// Work with specific section
let data_entries = get_section_entries(groups, "=== Section: Data ===")
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
// Clean processing pipeline
content
|> parse_ccl_string()
|> strip_section_headers(FixedPattern("==="))  // Remove visual headers
|> entries_to_ccl()                            // Convert to CCL
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

### Section Name Extraction
- **FixedPattern**: Use entire key as section name
- **PrefixSuffix**: Extract text between prefix and suffix
- **RegexPattern**: Use regex groups to extract name
- **Custom**: User provides extraction logic

## Integration Points

### With Existing CCL System
```gleam
// Combined with other features
content
|> parse_ccl_string()
|> strip_section_headers(FixedPattern("==="))   // Remove decorative headers  
|> filter_keys(["/", "#"])                      // Remove comments
|> entries_to_ccl()                            // Convert to CCL structure
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

### CCL Style with Nested Sections
```ccl
=== Database Configuration ===
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

=== Logging Options ===
logging =
  level = info
  file = /var/log/app.log
```

### INI Style with Indented Content
```ccl
[database]
database =
  host = localhost
  port = 5432

[server]
server =
  host = 0.0.0.0
  port = 8080

[logging]
logging =
  level = info
  file = /var/log/app.log
```

### Comment Style with Nested Sections
```ccl
# --- Database Configuration ---
database =
  primary =
    host = db1.example.com
    port = 5432
  replica =
    host = db2.example.com
    port = 5432

# --- Server Settings ---
server =
  host = 0.0.0.0
  port = 8080
  middleware =
    = cors
    = auth
    = logging

# --- Logging Options ---
logging =
  level = info
  outputs =
    = console
    = file
```

### Custom Decorative with Indented Sections
```ccl
/**** DATABASE SETTINGS ****/
database =
  connection =
    host = localhost
    port = 5432
    pool_size = 20

/**** SERVER CONFIG ****/
server =
  bind =
    host = 0.0.0.0
    port = 8080
  features =
    = ssl
    = compression
    = caching

/**** LOGGING SETUP ****/
logging =
  level = info
  destinations =
    file =
      path = /var/log/app.log
      rotate = true
    console =
      format = json
```

## Testing Requirements

- Parse various header patterns correctly
- Group entries under appropriate sections
- Handle entries before first section
- Extract section names accurately
- Filter headers while preserving other entries
- Support multiple header styles in same file
- Handle edge cases (empty sections, malformed headers)