// CCL Statistical Performance Benchmark
// Uses gleamy_bench for proper timing measurements with statistical analysis

import gleam/io
import gleam/int
import gleam/list
import gleam/string
import gleam/result
import gleamy/bench
import ccl_core
import ccl

pub fn main() {
  io.println("📊 CCL Statistical Benchmarking Suite")
  io.println("====================================")
  io.println("")
  
  // Run core parsing benchmarks
  run_parsing_benchmarks()
  
  io.println("")
  
  // Run object construction benchmarks
  run_construction_benchmarks()
  
  io.println("")
  
  // Run typed parsing overhead benchmarks
  run_typed_parsing_benchmarks()
  
  io.println("")
  io.println("✅ Statistical benchmark suite completed!")
}

pub fn run_parsing_benchmarks() {
  io.println("🚀 Core Parsing Performance (Statistical)")
  io.println("-----------------------------------------")
  
  let test_configs = [
    bench.Input("small_config", generate_small_config()),
    bench.Input("medium_config", generate_medium_config()),
    bench.Input("large_config", generate_large_config()),
  ]
  
  let parsing_functions = [
    bench.Function("parse_only", fn(config_text) { 
      ccl_core.parse(config_text) 
    }),
  ]
  
  bench.run(
    test_configs,
    parsing_functions,
    [bench.Duration(3000)]  // 3 second test duration per benchmark
  )
  |> bench.table([bench.IPS, bench.Min, bench.P(99)])
  |> io.println()
}

pub fn run_construction_benchmarks() {
  io.println("🏗️ Object Construction Performance (Statistical)")
  io.println("-----------------------------------------------")
  
  // First test parsing performance
  let construction_configs = [
    bench.Input("flat_10_entries", generate_flat_entries(10)),
    bench.Input("flat_100_entries", generate_flat_entries(100)),
    bench.Input("nested_shallow", generate_nested_entries(20, 2)),
    bench.Input("nested_deep", generate_nested_entries(10, 6)),
  ]
  
  let parsing_functions = [
    bench.Function("parse_to_entries", fn(config_text) {
      ccl_core.parse(config_text)
    }),
  ]
  
  bench.run(
    construction_configs,
    parsing_functions,
    [bench.Duration(3000)]
  )
  |> bench.table([bench.IPS, bench.Min, bench.P(99)])
  |> io.println()
  
  io.println("")
  
  // Then test object construction from pre-parsed entries
  let parsed_entries_configs = [
    bench.Input("flat_10_entries_parsed", 
      generate_flat_entries(10) |> ccl_core.parse() |> result.unwrap([])),
    bench.Input("flat_100_entries_parsed", 
      generate_flat_entries(100) |> ccl_core.parse() |> result.unwrap([])),
    bench.Input("nested_shallow_parsed", 
      generate_nested_entries(20, 2) |> ccl_core.parse() |> result.unwrap([])),
    bench.Input("nested_deep_parsed", 
      generate_nested_entries(10, 6) |> ccl_core.parse() |> result.unwrap([])),
  ]
  
  let construction_functions = [
    bench.Function("make_objects", fn(entries) {
      ccl_core.make_objects(entries)
    }),
  ]
  
  bench.run(
    parsed_entries_configs,
    construction_functions,
    [bench.Duration(3000)]
  )
  |> bench.table([bench.IPS, bench.Min, bench.P(99)])
  |> io.println()
}

pub fn run_typed_parsing_benchmarks() {
  io.println("🎯 Typed Parsing Overhead Analysis (Statistical)")
  io.println("-----------------------------------------------")
  
  // Pre-construct the CCL object for access pattern benchmarks
  let typed_config_text = generate_typed_test_config()
  let ccl_config = case ccl_core.parse(typed_config_text) {
    Ok(entries) -> ccl_core.make_objects(entries)
    Error(_) -> ccl_core.make_objects([])
  }
  
  let typed_configs = [
    bench.Input("ccl_config", ccl_config),
  ]
  
  let access_functions = [
    bench.Function("string_only_access", fn(config) {
      let _ = ccl_core.get_value(config, "server.port")
      let _ = ccl_core.get_value(config, "server.timeout")
      let _ = ccl_core.get_value(config, "server.ssl")
      config
    }),
    bench.Function("typed_access", fn(config) {
      let _ = ccl.get_int(config, "server.port")
      let _ = ccl.get_float(config, "server.timeout")
      let _ = ccl.get_bool(config, "server.ssl")
      config
    }),
    bench.Function("generic_typed_access", fn(config) {
      let _ = ccl.get_typed_value(config, "server.port")
      let _ = ccl.get_typed_value(config, "server.timeout")
      let _ = ccl.get_typed_value(config, "server.ssl")
      config
    }),
  ]
  
  bench.run(
    typed_configs,
    access_functions,
    [bench.Duration(3000)]
  )
  |> bench.table([bench.IPS, bench.Min, bench.P(99)])
  |> io.println()
}

// === TEST DATA GENERATORS ===

fn generate_small_config() -> String {
  "app.name = CCLBenchmark
app.version = 1.0.0
app.debug = true
server.host = localhost
server.port = 8080
server.ssl = false
server.timeout = 30.5
allowed_hosts =
  = localhost
  = 127.0.0.1"
}

fn generate_medium_config() -> String {
  "app.name = CCLBenchmark
app.version = 1.0.0
app.debug = true
app.environment = testing
server.host = localhost
server.port = 8080
server.ssl = false
server.timeout = 30.5
server.max_connections = 1000
server.keep_alive = true
database.host = localhost
database.port = 5432
database.name = testdb
database.username = testuser
database.password = testpass
database.pool_size = 25
database.query_timeout = 10.5
cache.enabled = true
cache.ttl = 300
cache.max_size = 1000
cache.compression = false
allowed_hosts =
  = localhost
  = 127.0.0.1
  = api.example.com
  = web.example.com
features =
  = user_auth
  = email_notifications
  = advanced_search
  = analytics
performance.max_requests = 5000
performance.timeout = 60.0
performance.retry_attempts = 3"
}

fn generate_large_config() -> String {
  let base_config = generate_medium_config()
  let additional_sections = list.range(1, 50)
    |> list.map(fn(i) {
      "
service" <> int.to_string(i) <> ".name = Service" <> int.to_string(i) <> "
service" <> int.to_string(i) <> ".port = " <> int.to_string(8000 + i) <> "
service" <> int.to_string(i) <> ".enabled = " <> case i % 2 {
        0 -> "true"
        _ -> "false"
      } <> "
service" <> int.to_string(i) <> ".timeout = " <> int.to_string(30 + i) <> ".5"
    })
    |> string.join("\n")
  
  base_config <> "\n\n# Generated Services\n" <> additional_sections
}

fn generate_flat_entries(count: Int) -> String {
  list.range(1, count)
  |> list.map(fn(i) { "key" <> int.to_string(i) <> " = value" <> int.to_string(i) })
  |> string.join("\n")
}

fn generate_nested_entries(count: Int, depth: Int) -> String {
  list.range(1, count)
  |> list.map(fn(i) {
    let nested_key = list.range(1, depth)
      |> list.map(fn(level) { "section" <> int.to_string(level) })
      |> string.join(".")
    nested_key <> ".key" <> int.to_string(i) <> " = nested_value" <> int.to_string(i)
  })
  |> string.join("\n")
}

fn generate_typed_test_config() -> String {
  "server.host = localhost
server.port = 8080
server.ssl = true
server.timeout = 30.5
server.connections = 100
app.debug = false
app.name = BenchmarkApp
database.enabled = true
database.max_pool = 25
database.retry_count = 3
cache.ttl = 300.0
cache.enabled = true"
}