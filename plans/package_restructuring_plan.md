# CCL Gleam Package Restructuring Plan

## Overview and Rationale

The goal is to transform the current monolithic CCL Gleam implementation into a well-structured monorepo with multiple packages that serve different use cases and complexity levels. This approach provides a clear path for users to adopt CCL incrementally, starting with core functionality and adding advanced features as needed.

### Core Philosophy
- **Core audience**: Users with barebones config needs who want to build richer systems on top
- **Minimal core**: Essential parsing and basic access functionality only
- **Opt-in complexity**: Advanced features are separate packages users can choose to include
- **Clear boundaries**: Each package has a well-defined responsibility and API surface

## Package Structure

### 1. ccl_core - Minimal Core Library

**Purpose**: Provides the essential CCL functionality for basic configuration parsing and access.

**Includes**:
- Core data types (`Entry`, `ParseError`, `CCL`)
- Basic parsing function (`parse()`)
- Fixpoint algorithm (`build_hierarchy()`)
- Raw string value accessors (`get_value()`, `get_values()`, `get_nested()`)
- Basic existence checks (`has_key()`)

**API Surface**:
```gleam
// Core types
pub type Entry {
  Entry(key: String, value: String)
}

pub type ParseError {
  ParseError(line: Int, reason: String)
}

pub type CCL {
  CCL(map: dict.Dict(String, CCL))
}

// Essential functions
pub fn parse(text: String) -> Result(List(Entry), ParseError)
pub fn build_hierarchy(entries: List(Entry)) -> CCL
pub fn get_value(ccl: CCL, path: String) -> Result(String, String)
pub fn get_values(ccl: CCL, path: String) -> List(String)
pub fn get_nested(ccl: CCL, path: String) -> Result(CCL, String)
pub fn has_key(ccl: CCL, path: String) -> Bool
pub fn get_keys(ccl: CCL, path: String) -> List(String)
pub fn empty_ccl() -> CCL
```

**Package Location**: `packages/ccl_core/`

**gleam.toml**:
```toml
name = "ccl_core"
version = "1.0.0"
description = "Minimal CCL parsing and access library"
target = "erlang"

[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
```

### 2. ccl - Full-Featured Library

**Purpose**: Provides the complete CCL experience with smart accessors, type detection, and convenience features.

**Includes**:
- Re-exports all ccl_core functionality
- Node type detection (`NodeType`, `node_type()`)
- Smart accessors (`get_smart_value()`, `get_list()`, `get_value_or_first()`)
- Utility functions (`get_all_paths()`, `pretty_print_ccl()`)
- Enhanced list handling

**API Surface**:
```gleam
// Re-export everything from ccl_core
pub use ccl_core.{
  type Entry, type ParseError, type CCL,
  parse, build_hierarchy, get_value, get_values, 
  get_nested, has_key, get_keys, empty_ccl
}

// Additional types and functions
pub type NodeType {
  SingleValue
  ListValue  
  ObjectValue
  Missing
}

pub fn node_type(ccl: CCL, path: String) -> NodeType
pub fn get_smart_value(ccl: CCL, path: String) -> Result(String, String)
pub fn get_list(ccl: CCL, path: String) -> Result(List(String), String)
pub fn get_value_or_first(ccl: CCL, path: String) -> Result(String, String)
pub fn get_all_paths(ccl: CCL) -> List(String)
pub fn pretty_print_ccl(ccl: CCL) -> String
```

**Package Location**: `packages/ccl/`

**gleam.toml**:
```toml
name = "ccl"
version = "1.0.0"
description = "Full-featured CCL library with smart accessors and type detection"
target = "erlang"

[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
ccl_core = "1.0.0"
```

### 3. ccl_typed - Type-Aware Parsing (Future Package)

**Purpose**: Provides type-safe parsing with compile-time guarantees and automatic type conversion.

**Planned Features**:
- Type-safe configuration schemas
- Automatic parsing to Gleam types
- Validation and error reporting
- Custom type decoders

**Package Location**: `packages/ccl_typed/`

### 4. ccl_json - JSON Integration (Optional Package)

**Purpose**: Provides JSON import/export functionality for CCL structures.

**Features**:
- Convert CCL to JSON
- Parse JSON as CCL
- Bidirectional conversion utilities

**Package Location**: `packages/ccl_json/`

**gleam.toml**:
```toml
name = "ccl_json"
version = "1.0.0"
description = "JSON integration for CCL"
target = "erlang"

[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
gleam_json = ">= 3.0.2 and < 4.0.0"
ccl_core = "1.0.0"
```

## Detailed Implementation Plan

### Phase 1: Core Extraction

1. **Create packages directory structure**:
   ```
   packages/
   ├── ccl_core/
   │   ├── gleam.toml
   │   ├── src/
   │   │   └── ccl_core.gleam
   │   └── test/
   │       └── ccl_core_test.gleam
   ```

2. **Extract core functionality** from current `src/ccl.gleam`:
   - Core types: `Entry`, `ParseError`, `CCL`, `ValueEntry`
   - Parsing: `parse()` function and all internal parsing helpers
   - Object construction: `build_hierarchy()` and fixpoint algorithm
   - Basic accessors: `get_value()`, `get_values()`, `get_nested()`, `has_key()`, `get_keys()`
   - Utility functions: `empty_ccl()`, CCL manipulation helpers

3. **Create ccl_core package**:
   - Move extracted code to `packages/ccl_core/src/ccl_core.gleam`
   - Create package-specific `gleam.toml`
   - Ensure all internal functions are properly scoped (private vs public)

### Phase 2: Full Library Package

1. **Create ccl package structure**:
   ```
   packages/ccl/
   ├── gleam.toml
   ├── src/
   │   ├── ccl.gleam        # Main module with re-exports + additional features
   │   └── ccl/
   │       ├── smart.gleam  # Smart accessors
   │       └── utils.gleam  # Utility functions
   ```

2. **Implement ccl package**:
   - Re-export all ccl_core functionality
   - Add node type detection (`NodeType`, `node_type()`, classification logic)
   - Add smart accessors (`get_smart_value()`, `get_list()`, `get_value_or_first()`)
   - Add utility functions (`get_all_paths()`, `pretty_print_ccl()`)

### Phase 3: Workspace Configuration

1. **Create root workspace configuration**:
   ```toml
   # Root gleam.toml
   [workspace]
   members = [
     "packages/ccl_core",
     "packages/ccl",
     "packages/ccl_json"
   ]
   ```

2. **Update root package** to depend on full ccl library for examples and testing

### Phase 4: Testing and Validation

1. **Create comprehensive test suites** for each package
2. **Validate API boundaries** - ensure ccl_core doesn't depend on advanced features
3. **Test integration** - verify ccl package properly extends ccl_core
4. **Update examples** to demonstrate both minimal and full usage patterns

## API Boundary Definitions

### ccl_core Boundaries

**MUST Include**:
- All parsing functionality (no external dependencies on smart features)
- Basic CCL data structure and manipulation
- Raw string value access (get_value, get_values, get_nested)
- Essential utilities (has_key, get_keys, empty_ccl)

**MUST NOT Include**:
- Node type detection or classification
- Smart accessors that make assumptions about data structure
- Pretty printing or debugging utilities
- Any convenience features that aren't essential for basic usage

### ccl Package Boundaries

**MUST Include**:
- All ccl_core functionality (via re-export)
- Smart accessors that provide convenience and error handling
- Node type detection and classification
- Utility functions for debugging and introspection

**MUST NOT Include**:
- Type-safe parsing (belongs in ccl_typed)
- External format conversion (belongs in format-specific packages)
- Domain-specific configuration helpers

## Migration Strategy

### For Existing Users

1. **No Breaking Changes**: Existing code using the current ccl_gleam package continues to work
2. **Gradual Migration Path**: 
   - Current package becomes equivalent to the full `ccl` package
   - Users can optionally switch to `ccl_core` for minimal installations
   - Advanced users can adopt `ccl_typed` when available

### Migration Steps

1. **Phase 1 - Internal Restructure**: 
   - Create packages without changing external API
   - Current ccl_gleam depends on and re-exports from ccl package

2. **Phase 2 - Package Publication**:
   - Publish ccl_core and ccl as separate packages
   - Update documentation to recommend appropriate package choice

3. **Phase 3 - Deprecation** (optional, future):
   - Mark original ccl_gleam as legacy
   - Encourage migration to appropriate specialized package

## Testing Strategy

### ccl_core Testing
- **Focus**: Core parsing, object construction, basic access
- **Test Categories**:
  - Parsing edge cases and error handling
  - Fixpoint algorithm correctness
  - Basic value retrieval and navigation
  - Performance with large configurations

### ccl Package Testing  
- **Focus**: Smart accessors, type detection, utilities
- **Test Categories**:
  - Node type classification accuracy
  - Smart accessor error messages and behavior
  - Integration between core and smart features
  - Pretty printing and debugging utilities

### Integration Testing
- **Cross-package compatibility**
- **Version compatibility between ccl_core and ccl**
- **Example applications using different package combinations**

## File Organization

### Root Structure (After Migration)
```
ccl_gleam/                    # Workspace root
├── gleam.toml                # Workspace configuration
├── README.md                 # Overall project documentation
├── docs/                     # Shared documentation
├── examples/                 # Cross-package examples
├── packages/
│   ├── ccl_core/            # Minimal library
│   │   ├── gleam.toml
│   │   ├── README.md        # Core-specific docs
│   │   ├── src/ccl_core.gleam
│   │   └── test/ccl_core_test.gleam
│   ├── ccl/                 # Full library  
│   │   ├── gleam.toml
│   │   ├── README.md        # Full library docs
│   │   ├── src/
│   │   │   ├── ccl.gleam
│   │   │   └── ccl/
│   │   │       ├── smart.gleam
│   │   │       └── utils.gleam
│   │   └── test/
│   │       ├── ccl_test.gleam
│   │       └── ccl/
│   │           ├── smart_test.gleam
│   │           └── utils_test.gleam
│   └── ccl_json/            # JSON integration
│       ├── gleam.toml
│       ├── src/ccl_json.gleam
│       └── test/ccl_json_test.gleam
└── build/                   # Build artifacts
```

## Benefits of This Structure

1. **Clear Separation of Concerns**: Each package has a focused responsibility
2. **Flexible Adoption**: Users can choose the complexity level they need
3. **Maintainable Dependencies**: Clear dependency graph prevents circular references
4. **Future Growth**: Easy to add specialized packages (ccl_typed, ccl_yaml, etc.)
5. **Testing Isolation**: Each package can be tested independently
6. **Documentation Clarity**: Package-specific docs reduce confusion

## Implementation Timeline

1. **Week 1-2**: Core extraction and ccl_core package creation
2. **Week 3**: Full ccl package implementation and testing
3. **Week 4**: Workspace configuration and integration testing
4. **Week 5**: Documentation updates and example applications
5. **Week 6**: Package publication and migration documentation

## Success Criteria

- [ ] ccl_core package compiles and passes all tests independently
- [ ] ccl package properly extends ccl_core without code duplication
- [ ] All existing functionality remains available through the ccl package
- [ ] Clear documentation explains when to use each package
- [ ] Examples demonstrate both minimal (ccl_core) and full (ccl) usage
- [ ] Performance impact of package separation is negligible
- [ ] Migration path from current monolithic structure is seamless