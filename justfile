#!/usr/bin/env just --justfile

# Workspace packages
packages := "ccl_types ccl_core ccl_test_loader ccl"

# Common aliases for faster development
alias b := build
alias t := test
alias tc := test-counts
alias c := check
alias f := format

# Default recipe - shows available commands
default:
    @just --list

# Helper to run gleam command on all packages
_run-all cmd:
	@echo "Running '{{cmd}}' on all packages..."
	@for package in {{packages}}; do \
		echo "→ $package"; \
		cd packages/$package && gleam {{cmd}} || exit 1; \
		cd - > /dev/null; \
	done
	@echo "✅ Completed successfully!"

# Check all packages
check:
	@just _run-all check

# Test all packages  
test:
	@just _run-all test

# Test all packages with assertion counting
test-counts:
	@echo "Running tests with assertion counting..."
	@cd packages/ccl_test_loader && gleam run -m assertion_counting_demo

# Run both standard tests and assertion counting
test-all: test test-counts

# Build all packages
build:
	@just _run-all build

# Format all packages
format:
	@just _run-all format

# Check formatting for all packages  
format-check:
	@just _run-all "format --check"

# Run all quality checks
lint: check format-check

# Run command on a specific package
run-on package cmd:
	@echo "Running '{{cmd}}' on {{package}}..."
	@cd packages/{{package}} && gleam {{cmd}}

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build
	@for package in {{packages}}; do \
		echo "→ cleaning packages/$package/build"; \
		rm -rf packages/$package/build; \
	done
	@echo "✅ Clean completed!"

# Run full CI pipeline
ci: lint build test