// Typed Parsing Overhead Benchmarks

import gleamy_bench.{benchmark, Duration}
import ccl_core
import ccl
import gleam/result
import gleam/io

pub fn main() {
  io.println("=== CCL Typed Parsing Overhead Benchmarks ===")
  io.println("")
  
  // Compare string-only vs typed parsing performance
  run_type_parsing_overhead_benchmark()
  
  io.println("")
  io.println("=== Type Parsing Feature Comparison ===")
  io.println("")
  
  // Compare different typed parsing features
  run_feature_comparison_benchmark()
}

/// Measure overhead of typed parsing vs string-only access
fn run_type_parsing_overhead_benchmark() {
  let mixed_type_config = generate_mixed_type_config()
  
  let test_configs = [
    #("mixed_types_config", mixed_type_config),
  ]
  
  // Parse config once and reuse for access benchmarks
  let parsed_config = case ccl_core.parse(mixed_type_config) {
    Ok(entries) -> ccl_core.make_objects(entries)
    Error(_) -> ccl_core.empty_ccl()
  }
  
  let config_access_methods = [
    // String-only access (baseline)
    #("string_access_baseline", fn(_) {
      let _ = ccl_core.get_value(parsed_config, "server.port")        // "8080"
      let _ = ccl_core.get_value(parsed_config, "server.timeout")     // "30.5"  
      let _ = ccl_core.get_value(parsed_config, "server.ssl")         // "true"
      let _ = ccl_core.get_value(parsed_config, "server.host")        // "localhost"
      Ok("completed")
    }),
    
    // Basic typed access
    #("typed_access_basic", fn(_) {
      let _ = ccl.get_int(parsed_config, "server.port")          // Ok(8080)
      let _ = ccl.get_float(parsed_config, "server.timeout")     // Ok(30.5)
      let _ = ccl.get_bool(parsed_config, "server.ssl")          // Ok(True)
      let _ = ccl.get_value(parsed_config, "server.host")        // Ok("localhost")
      Ok("completed")
    }),
    
    // Generic typed access
    #("generic_typed_access", fn(_) {
      let _ = ccl.get_typed_value(parsed_config, "server.port")
      let _ = ccl.get_typed_value(parsed_config, "server.timeout") 
      let _ = ccl.get_typed_value(parsed_config, "server.ssl")
      let _ = ccl.get_typed_value(parsed_config, "server.host")
      Ok("completed")
    }),
    
    // Typed access with custom options
    #("typed_with_options", fn(_) {
      let options = ccl.smart_options()
      let _ = ccl.get_typed_value_with_options(parsed_config, "server.port", options)
      let _ = ccl.get_typed_value_with_options(parsed_config, "server.timeout", options)
      let _ = ccl.get_typed_value_with_options(parsed_config, "server.ssl", options)
      let _ = ccl.get_typed_value_with_options(parsed_config, "server.host", options)
      Ok("completed")
    }),
  ]
  
  benchmark(
    test_configs,
    config_access_methods,
    Duration(3000)
  )
}

/// Compare different typed parsing features
fn run_feature_comparison_benchmark() {
  let test_config = generate_comprehensive_config()
  
  let parsed_config = case ccl_core.parse(test_config) {
    Ok(entries) -> ccl_core.make_objects(entries)
    Error(_) -> ccl_core.empty_ccl()
  }
  
  let config_inputs = [
    #("comprehensive_config", "unused"), // We use parsed_config directly
  ]
  
  let parsing_features = [
    // Core value access
    #("core_string_values", fn(_) {
      let _ = ccl_core.get_value(parsed_config, "app.name")
      let _ = ccl_core.get_value(parsed_config, "app.version") 
      let _ = ccl_core.get_value(parsed_config, "database.host")
      Ok("completed")
    }),
    
    // Integer parsing
    #("integer_parsing", fn(_) {
      let _ = ccl.get_int(parsed_config, "server.port")
      let _ = ccl.get_int(parsed_config, "database.port")
      let _ = ccl.get_int(parsed_config, "redis.port")
      Ok("completed")
    }),
    
    // Float parsing
    #("float_parsing", fn(_) {
      let _ = ccl.get_float(parsed_config, "server.timeout")
      let _ = ccl.get_float(parsed_config, "database.query_timeout")
      let _ = ccl.get_float(parsed_config, "cache.ttl")
      Ok("completed")
    }),
    
    // Boolean parsing
    #("boolean_parsing", fn(_) {
      let _ = ccl.get_bool(parsed_config, "server.ssl")
      let _ = ccl.get_bool(parsed_config, "database.ssl_mode")
      let _ = ccl.get_bool(parsed_config, "features.debug")
      Ok("completed")
    }),
    
    // List access
    #("list_processing", fn(_) {
      let _ = ccl.get_list(parsed_config, "allowed_hosts")
      let _ = ccl.get_list(parsed_config, "feature_flags")
      Ok("completed")
    }),
    
    // Nested object access
    #("nested_access", fn(_) {
      case ccl_core.get_nested(parsed_config, "server") {
        Ok(server_config) -> {
          let _ = ccl.get_int(server_config, "port")
          let _ = ccl.get_bool(server_config, "ssl")
          Ok("completed")
        }
        Error(_) -> Ok("failed")
      }
    }),
    
    // Error handling overhead (accessing non-existent keys)
    #("error_handling", fn(_) {
      let _ = ccl.get_int(parsed_config, "nonexistent.key")
      let _ = ccl.get_bool(parsed_config, "another.missing.key") 
      let _ = ccl.get_float(parsed_config, "not.found")
      Ok("completed")
    }),
  ]
  
  benchmark(
    config_inputs,
    parsing_features,
    Duration(3000)
  )
}

// === TEST DATA GENERATORS ===

fn generate_mixed_type_config() -> String {
  "
# Mixed Type Configuration
server.host = localhost
server.port = 8080
server.timeout = 30.5
server.ssl = true
server.max_connections = 1000
server.keep_alive = true

database.host = db.example.com
database.port = 5432
database.connections = 25
database.query_timeout = 10.5
database.ssl_mode = false

cache.enabled = true
cache.ttl = 300.0
cache.max_size = 1000
cache.compression = false
"
  |> string.trim()
}

fn generate_comprehensive_config() -> String {
  "
# Comprehensive Configuration for Benchmarking
app.name = BenchmarkApp
app.version = 1.2.3
app.environment = testing

# Server Configuration
server.host = 0.0.0.0
server.port = 8080
server.timeout = 30.5
server.ssl = true
server.max_connections = 2000
server.keep_alive = true
server.compression = false

# Database Configuration  
database.host = db.example.com
database.port = 5432
database.name = benchmark_db
database.connections = 50
database.query_timeout = 15.5
database.ssl_mode = true
database.pool_timeout = 5.0

# Redis Configuration
redis.host = redis.example.com
redis.port = 6379
redis.database = 0
redis.timeout = 2.5
redis.connections = 10

# Cache Settings
cache.enabled = true
cache.ttl = 600.0
cache.max_size = 10000
cache.compression = true

# Feature Flags
features.debug = false
features.logging = true
features.metrics = true
features.tracing = false

# Allowed Hosts List
allowed_hosts =
  = localhost
  = 127.0.0.1
  = api.example.com
  = web.example.com
  = admin.example.com

# Feature Flags List
feature_flags =
  = user_registration
  = email_notifications
  = advanced_search
  = beta_features
  = analytics_tracking

# Performance Settings
performance.max_requests = 10000
performance.timeout = 60.0
performance.retry_attempts = 3
performance.circuit_breaker = true
"
  |> string.trim()
}

// Helper to import string module
@external(erlang, "string", "trim")
fn string_trim(s: String) -> String