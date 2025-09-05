// CCL Benchmark Runner
// Orchestrates all benchmark suites

import benchmarks/core_parsing/parsing_benchmark
import benchmarks/typed_parsing/type_overhead_benchmark
import gleam/io

pub fn main() {
  io.println("🔥 CCL Gleam Performance Benchmarks")
  io.println("====================================")
  io.println("")

  io.println("Starting benchmark suite...")
  io.println("")

  // Run core parsing benchmarks
  io.println("📊 Phase 1: Core Parsing Performance")
  parsing_benchmark.main()

  io.println("")
  io.println("📊 Phase 2: Typed Parsing Overhead")
  type_overhead_benchmark.main()

  io.println("")
  io.println("✅ All benchmarks completed!")
  io.println("")
  io.println("📋 Summary:")
  io.println("- Core parsing performance measured across file sizes")
  io.println("- Typed parsing overhead quantified vs string-only access")
  io.println("- Real-world configuration scenarios benchmarked")
  io.println("")
  io.println("Use these results to:")
  io.println("- Identify performance bottlenecks")
  io.println("- Track performance regressions")
  io.println("- Optimize hot paths")
  io.println("- Compare with other config formats")
}
