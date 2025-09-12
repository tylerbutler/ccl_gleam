// Core CCL Parsing Benchmarks

import ccl
import ccl_core
import gleam/io
import gleam/result
import gleamy_bench.{Duration, benchmark}

// Import test data generators
import benchmarks/test_data/generators/ccl_generator

pub fn main() {
  io.println("=== CCL Core Parsing Benchmarks ===")
  io.println("")

  // Run parsing performance benchmarks
  run_basic_parsing_benchmark()

  io.println("")
  io.println("=== File Size Scaling Benchmarks ===")
  io.println("")

  // Run file size scaling benchmarks
  run_file_size_benchmarks()

  io.println("")
  io.println("=== Real-World Configuration Benchmarks ===")
  io.println("")

  // Run realistic configuration benchmarks
  run_realistic_benchmarks()
}

/// Basic parsing performance benchmark
fn run_basic_parsing_benchmark() {
  let test_inputs = [
    #("simple_kv", "key = value\nother = 123\nenabled = true"),
    #("small_config", ccl_generator.generate_small_config()),
    #("web_server", ccl_generator.generate_web_server_config()),
  ]

  let parsing_functions = [
    #("parse_only", fn(text) { ccl_core.parse(text) }),
    #("parse_and_objects", fn(text) {
      ccl_core.parse(text)
      |> result.map(ccl_core.build_hierarchy)
    }),
    #("full_pipeline", fn(text) {
      case ccl_core.parse(text) {
        Ok(entries) -> {
          let config = ccl_core.build_hierarchy(entries)
          // Simulate accessing a few values
          let _ = ccl_core.get_value(config, "server.port")
          let _ = ccl_core.get_value(config, "database.host")
          Ok(config)
        }
        Error(e) -> Error(e)
      }
    }),
  ]

  benchmark(
    test_inputs,
    parsing_functions,
    Duration(3000),
    // 3 second test duration per combination
  )
}

/// File size scaling benchmark
fn run_file_size_benchmarks() {
  let size_inputs = [
    #("small_1kb", ccl_generator.generate_small_config()),
    #("medium_100kb", ccl_generator.generate_medium_config()),
    #("large_1mb", ccl_generator.generate_large_config()),
    #("feature_flags_1k", ccl_generator.generate_feature_flags_config(1000)),
    #("nested_deep", ccl_generator.generate_nested_config(8, 5)),
  ]

  let parsing_operations = [
    #("parse_text_to_entries", fn(text) { ccl_core.parse(text) }),
    #("build_object_structure", fn(text) {
      ccl_core.parse(text)
      |> result.map(ccl_core.build_hierarchy)
    }),
  ]

  benchmark(
    size_inputs,
    parsing_operations,
    Duration(5000),
    // 5 second test duration for larger files
  )
}

/// Real-world configuration scenarios
fn run_realistic_benchmarks() {
  // Simulate common configuration access patterns
  let config_scenarios = [
    #("app_config", generate_application_config()),
    #("microservice_config", generate_microservice_config()),
    #("database_config", generate_database_config()),
  ]

  let access_patterns = [
    #("single_value_lookup", fn(config_text) {
      case ccl_core.parse(config_text) {
        Ok(entries) -> {
          let config = ccl_core.build_hierarchy(entries)
          ccl_core.get_value(config, "server.port")
        }
        Error(e) -> Error(string.inspect(e))
      }
    }),
    #("multiple_value_access", fn(config_text) {
      case ccl_core.parse(config_text) {
        Ok(entries) -> {
          let config = ccl_core.build_hierarchy(entries)
          let _ = ccl_core.get_value(config, "server.host")
          let _ = ccl_core.get_value(config, "server.port")
          let _ = ccl_core.get_value(config, "database.host")
          let _ = ccl_core.get_value(config, "database.port")
          let _ = ccl_core.get_values(config, "allowed_hosts")
          Ok("success")
        }
        Error(e) -> Error(string.inspect(e))
      }
    }),
    #("nested_object_access", fn(config_text) {
      case ccl_core.parse(config_text) {
        Ok(entries) -> {
          let config = ccl_core.build_hierarchy(entries)
          case ccl_core.get_nested(config, "server") {
            Ok(server_config) -> {
              let _ = ccl_core.get_value(server_config, "host")
              let _ = ccl_core.get_value(server_config, "port")
              Ok("success")
            }
            Error(e) -> Error(e)
          }
        }
        Error(e) -> Error(string.inspect(e))
      }
    }),
  ]

  benchmark(config_scenarios, access_patterns, Duration(3000))
}

// === TEST DATA GENERATORS ===

fn generate_application_config() -> String {
  "
# Application Configuration
app.name = MyApplication
app.version = 2.1.0
app.debug = false
app.environment = production

# Server Configuration
server.host = 0.0.0.0
server.port = 8080
server.ssl.enabled = true
server.ssl.cert_file = /etc/ssl/cert.pem
server.ssl.key_file = /etc/ssl/private.key
server.request_timeout = 30.0
server.max_connections = 1000

# Database Configuration
database.host = db.example.com
database.port = 5432
database.name = myapp_prod
database.username = dbuser
database.password = secure_password123
database.pool_size = 20
database.query_timeout = 10

# Allowed Hosts
allowed_hosts =
  = localhost
  = api.example.com
  = web.example.com
  = cdn.example.com

# Feature Flags
features.user_registration = true
features.email_notifications = true
features.advanced_search = false
features.beta_dashboard = false
"
  |> string.trim()
}

fn generate_microservice_config() -> String {
  "
# Microservices Configuration
services.auth.endpoint = https://auth.example.com
services.auth.timeout = 30.0
services.auth.retries = 3

services.user.endpoint = https://user-service.example.com  
services.user.timeout = 15.0
services.user.retries = 2

services.payment.endpoint = https://payment.example.com
services.payment.timeout = 45.0
services.payment.retries = 5

services.notification.endpoint = https://notifications.example.com
services.notification.timeout = 10.0
services.notification.retries = 1

# Circuit Breaker Settings
circuit_breaker.failure_threshold = 5
circuit_breaker.recovery_timeout = 60
circuit_breaker.request_volume_threshold = 20

# Rate Limiting
rate_limit.requests_per_minute = 1000
rate_limit.burst_size = 100

# Monitoring Endpoints
health_check.enabled = true
health_check.interval = 30
metrics.enabled = true
metrics.port = 9090
"
  |> string.trim()
}

fn generate_database_config() -> String {
  "
# Database Configuration
primary.host = db1.example.com
primary.port = 5432
primary.database = myapp_production
primary.username = app_user
primary.password = secure_db_password
primary.ssl_mode = require
primary.connection_timeout = 5
primary.pool_size = 25

replica.host = db2.example.com
replica.port = 5432
replica.database = myapp_production  
replica.username = readonly_user
replica.password = readonly_password
replica.ssl_mode = require
replica.connection_timeout = 5
replica.pool_size = 15

# Redis Configuration
redis.host = redis.example.com
redis.port = 6379
redis.database = 0
redis.password = redis_password
redis.pool_size = 10
redis.timeout = 3

# Connection Pool Settings
pool.max_connections = 100
pool.idle_timeout = 300
pool.checkout_timeout = 5
pool.max_lifetime = 3600

# Query Settings
queries.slow_query_threshold = 1.0
queries.log_slow_queries = true
queries.max_query_time = 30.0
"
  |> string.trim()
}

// Helper to import string module
@external(erlang, "string", "trim")
fn string_trim(s: String) -> String
