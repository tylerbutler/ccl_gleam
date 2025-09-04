#!/usr/bin/env just --justfile

# Workspace packages
packages := "ccl_core ccl ccl_test_loader"

# Common aliases for faster development
alias b := build
alias t := test
alias l := lint
alias f := fix
alias c := check
alias ba := build-all
alias ta := test-all

# Default recipe - shows available commands
default:
    @just --list

build: build-all

check:
	gleam check

test:
	gleam test

# Format source code
format:
	gleam format

# Check if code is formatted without changing it
format-check:
	gleam format --check

# Check for unused exports
cleam:
	gleam run -m cleam

# Run all linting checks
lint: check format-check cleam

# Fix formatting and run checks
fix: format check

# Build a specific package
build-package package:
	@echo "Building {{package}}..."
	@cd packages/{{package}} && gleam build

# Test a specific package  
test-package package:
	@echo "Testing {{package}}..."
	@cd packages/{{package}} && gleam test

# Build all packages in workspace
build-all:
	@echo "Building all packages..."
	@for package in {{packages}}; do \
		echo "Building $package..."; \
		cd packages/$package && gleam build || exit 1; \
		cd - > /dev/null; \
	done
	@echo "Building root package..."
	@gleam build
	@echo "All packages built successfully!"

# Test all packages in workspace
test-all:
	@echo "Testing all packages..."
	@for package in {{packages}}; do \
		echo "Testing $package..."; \
		cd packages/$package && gleam test || exit 1; \
		cd - > /dev/null; \
	done
	@echo "Testing root package..."
	@gleam test
	@echo "All tests completed!"

# Clean build artifacts
clean:
	rm -rf build
	@for package in {{packages}}; do \
		rm -rf packages/$package/build; \
	done

# Run full CI pipeline
ci: format-check check test

# Run full CI pipeline for all packages
ci-all: format-check build-all test-all

# === BENCHMARK TASKS ===

# Run all benchmarks
bench: bench-statistical bench-comparison bench-memory bench-demo

# Run statistical performance benchmarks
bench-statistical:
	@echo "🔥 Running CCL Statistical Benchmarks..."
	@gleam run --module ccl_statistical_benchmark

# Run performance comparison with baselines
bench-comparison:
	@echo "⚡ Running CCL Performance Comparison..."
	@gleam run --module ccl_json_comparison

# Run memory usage analysis
bench-memory:
	@echo "🧠 Running CCL Memory Analysis..."
	@gleam run --module ccl_memory_profiler

# Run simple benchmark demo
bench-demo:
	@echo "📊 Running CCL Benchmark Demo..."
	@gleam run --module ccl_benchmark_demo

# Run quick performance check (statistical only)
bench-quick: bench-statistical

# Run comprehensive performance analysis
bench-full: build bench-statistical bench-comparison bench-memory
	@echo ""
	@echo "✅ Full performance analysis completed!"
	@echo "📝 See plans/performance_analysis.md for detailed results"

# Clean and run all benchmarks (for clean measurement)
bench-clean: clean build bench-full
