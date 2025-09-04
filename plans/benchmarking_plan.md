# CCL Gleam Benchmarking Plan

Comprehensive performance testing strategy for the CCL Gleam implementation.

## Executive Summary

This benchmarking plan evaluates CCL Gleam performance across multiple dimensions: parsing speed, memory usage, throughput, and feature overhead. We compare against industry-standard config formats and measure the cost of CCL's unique features like typed parsing and the fixpoint algorithm.

## Tools and Infrastructure

### Primary Benchmarking Tools

**1. gleamy_bench** (Primary Framework)
- Native Gleam benchmarking library
- Measures execution time with statistical analysis
- Supports setup functions for complex scenarios
- Duration configuration for reliable measurements

**2. BEAM VM Profiling Tools**
- **fprof**: Detailed execution time analysis (high overhead)
- **eprof**: Function call time breakdown (moderate overhead)  
- **observer**: Real-time system monitoring and memory analysis
- **cprof**: Function call counting with minimal overhead

**3. System-Level Tools**
- **perf**: Linux system-level profiling (when JIT enabled)
- **Memory profilers**: Track heap usage and GC pressure

### Test Data Generation

**Synthetic CCL Generator**
```gleam
pub type BenchmarkConfig {
  BenchmarkConfig(
    file_size: FileSize,        // Small, Medium, Large, Huge
    nesting_depth: Int,         // 1-10 levels deep
    list_density: Float,        // 0.0-1.0 ratio of list entries
    comment_density: Float,     // 0.0-1.0 ratio of comment lines
    key_complexity: KeyStyle,   // Simple, Dotted, Mixed
    value_types: List(ValueType) // String, Int, Float, Bool, Mixed
  )
}
```

**Real-World CCL Examples**
- Application configurations (web servers, databases)
- Environment-specific configs (dev, staging, prod)
- Complex nested structures (microservices, feature flags)
- Large lists (allowed IPs, feature toggles)

## Benchmarking Dimensions

### 1. Core Parsing Performance

**Metrics:**
- **Parse Time**: Milliseconds to convert text → List(Entry)
- **Throughput**: MB/s or entries/second processing rate
- **Memory Usage**: Peak heap during parsing
- **GC Pressure**: Garbage collection frequency/duration

**Test Cases:**
```
Small Files:    1KB - 10KB   (typical app configs)
Medium Files:   10KB - 1MB   (complex enterprise configs)
Large Files:    1MB - 10MB   (config aggregation scenarios)
Huge Files:     10MB+        (stress testing limits)
```

**Baseline Comparisons:**
- JSON parsing (gleam_json)
- YAML parsing (if available)
- Raw string processing

### 2. Object Construction Performance

**Fixpoint Algorithm Analysis:**
- Time complexity with nesting depth
- Memory usage during object construction
- Performance vs naive nested maps

**Test Scenarios:**
```ccl
# Flat structure (baseline)
key1 = value1
key2 = value2
...

# Nested structure (scaling test)
a.b.c.d.e = deep_value
x.y.z = nested_value
...

# List-heavy structure
lists =
  = item1
  = item2
  = ...
```

### 3. Typed Parsing Overhead

**Cost Analysis:**
- String parsing vs typed parsing
- Type inference performance
- Error detection overhead

**Comparison Matrix:**
```
Core CCL:         Text → List(Entry) → CCL
+ Type Layer:     CCL → get_int() / get_bool() etc.
+ Error Context:  Enhanced error messages
+ Options:        ParseOptions configurability
```

### 4. Feature-Specific Benchmarks

**Comment Filtering:**
- Impact of comment density on parsing
- Cost of `filter_keys()` operations
- Memory usage with/without comments

**List Processing:**
- `get_list()` vs `get_values()` performance
- Empty-key vs array-style access patterns
- Large list handling (1k, 10k, 100k items)

**Nested Access:**
- Dot notation path resolution
- Deep nesting performance (1-20 levels)
- `get_nested()` vs direct path access

## Test Scenarios and Workloads

### Scenario 1: Web Server Configuration
```ccl
# Realistic 5KB config file
server.host = 0.0.0.0
server.port = 8080
server.ssl.enabled = true
...
database.connections =
  = postgres://db1/myapp
  = postgres://db2/myapp
...
```

**Metrics:** Parse time, memory usage, type parsing overhead

### Scenario 2: Microservices Configuration
```ccl
# Large 500KB aggregated config
service.auth.endpoint = https://auth.example.com
service.auth.timeout = 30.0
...
# 50+ services with nested config
```

**Metrics:** Scaling behavior, fixpoint algorithm performance

### Scenario 3: Feature Flag Management
```ccl
# 10k+ feature flags
flags =
  = user_registration
  = email_notifications
  ...
# Followed by detailed flag configurations
```

**Metrics:** List processing, memory efficiency, lookup performance

### Scenario 4: Error Handling Stress Test
```ccl
# Intentionally malformed config
server.port = not_a_number
timeout = 30,5  # comma instead of dot
enabled = maybe # invalid boolean
...
```

**Metrics:** Error detection overhead, error message generation cost

## Performance Targets and Acceptance Criteria

### Speed Benchmarks
- **Small files (< 10KB)**: < 1ms parsing
- **Medium files (< 1MB)**: < 100ms parsing  
- **Large files (< 10MB)**: < 1s parsing
- **Throughput**: > 50MB/s for typical configs

### Memory Benchmarks
- **Memory efficiency**: < 5x input size in memory
- **GC pressure**: Minimal allocations during parsing
- **Peak memory**: Linear growth with input size

### Feature Overhead
- **Typed parsing**: < 50% overhead vs string-only
- **Error context**: < 20% overhead for error cases
- **Comment filtering**: < 10% overhead vs uncommented

### Comparison Targets
- **vs JSON**: Acceptable if within 2-3x JSON parsing speed
- **vs YAML**: Should be competitive or faster
- **vs OCaml reference**: Comparable performance expected

## Benchmarking Implementation

### 1. Benchmark Suite Structure
```
benchmarks/
├── core_parsing/
│   ├── small_files_test.gleam
│   ├── large_files_test.gleam  
│   └── comparison_test.gleam
├── object_construction/
│   ├── fixpoint_algorithm_test.gleam
│   └── nesting_performance_test.gleam
├── typed_parsing/
│   ├── type_overhead_test.gleam
│   └── error_handling_test.gleam
├── features/
│   ├── comment_filtering_test.gleam
│   ├── list_processing_test.gleam
│   └── nested_access_test.gleam
└── test_data/
    ├── generators/
    └── samples/
```

### 2. Example Benchmark Implementation
```gleam
import gleamy_bench.{benchmark, Duration}
import ccl
import ccl_core

pub fn main() {
  benchmark(
    [
      #("small_config", generate_small_config()),
      #("medium_config", generate_medium_config()), 
      #("large_config", generate_large_config())
    ],
    [
      #("core_parsing", fn(config_text) { 
        ccl_core.parse(config_text) 
      }),
      #("full_pipeline", fn(config_text) {
        ccl_core.parse(config_text)
        |> result.map(ccl_core.make_objects)
      }),
      #("typed_parsing", fn(config_text) {
        let config = ccl_core.parse(config_text)
          |> result.unwrap([])
          |> ccl_core.make_objects()
        ccl.get_int(config, "server.port")
      })
    ],
    Duration(5000)  // 5 second test duration
  )
}
```

### 3. Memory Profiling Integration
```gleam
// Use observer for real-time memory analysis
// Profile with: gleam run --target erlang -- +OBSERVER
pub fn profile_memory_usage() {
  // :observer.start() equivalent in Gleam
  // Monitor heap growth during parsing
}
```

## Reporting and Analysis

### 1. Performance Dashboard
- Automated benchmarking in CI/CD
- Historical performance tracking
- Regression detection alerts

### 2. Detailed Reports
- **Execution profiles**: Function-level timing
- **Memory analysis**: Allocation patterns, GC behavior
- **Scaling characteristics**: Performance vs input size
- **Comparison matrices**: CCL vs other formats

### 3. Optimization Targets
Based on profiling results, identify:
- Hot paths for optimization
- Memory allocation bottlenecks
- Algorithm improvements (fixpoint, parsing)
- Type parsing optimizations

## Implementation Timeline

**Phase 1: Foundation (Week 1)**
- Set up gleamy_bench framework
- Implement test data generators
- Create basic parsing benchmarks

**Phase 2: Core Metrics (Week 2)**
- Comprehensive parsing performance tests
- Object construction benchmarking
- Memory profiling integration

**Phase 3: Feature Analysis (Week 3)**
- Typed parsing overhead measurement
- Comment filtering performance
- List and nested access benchmarks

**Phase 4: Comparisons (Week 4)**
- JSON/YAML comparison benchmarks
- OCaml reference comparison (if feasible)
- Real-world scenario testing

**Phase 5: Analysis & Optimization (Week 5)**
- Results analysis and reporting
- Performance optimization implementation
- Regression testing setup

## Success Criteria

**Benchmarking Infrastructure:**
- ✅ Comprehensive test suite covering all major features
- ✅ Automated performance regression detection
- ✅ Clear performance baselines established

**Performance Results:**
- ✅ CCL parsing within 3x of JSON parsing speed
- ✅ Memory usage scales linearly with input size
- ✅ Typed parsing overhead < 50% of core parsing
- ✅ No performance regressions in future releases

**Analysis Insights:**
- ✅ Clear understanding of performance bottlenecks
- ✅ Optimization roadmap based on profiling data
- ✅ Performance characteristics documented for users

This benchmarking plan provides a solid foundation for understanding and optimizing CCL Gleam performance across all critical dimensions.