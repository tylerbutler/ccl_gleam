#!/usr/bin/env just --justfile

# Workspace packages
packages := "ccl_types ccl_core ccl_test_loader ccl"

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

# Check all packages
check:
	@echo "Checking all packages..."
	@for package in {{packages}}; do \
		echo "Checking $package..."; \
		cd packages/$package && gleam check || exit 1; \
		cd - > /dev/null; \
	done

# Test all packages
test:
	@echo "Testing all packages..."
	@for package in {{packages}}; do \
		echo "Testing $package..."; \
		cd packages/$package && gleam test || exit 1; \
		cd - > /dev/null; \
	done

# Format all packages
format:
	@echo "Formatting all packages..."
	@for package in {{packages}}; do \
		echo "Formatting $package..."; \
		cd packages/$package && gleam format; \
		cd - > /dev/null; \
	done

# Check formatting for all packages
format-check:
	@echo "Checking formatting for all packages..."
	@for package in {{packages}}; do \
		echo "Checking format for $package..."; \
		cd packages/$package && gleam format --check || exit 1; \
		cd - > /dev/null; \
	done

# Run all linting checks
lint: check format-check

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
	@echo "All packages built successfully!"

# Test all packages in workspace
test-all:
	@echo "Testing all packages..."
	@for package in {{packages}}; do \
		echo "Testing $package..."; \
		cd packages/$package && gleam test || exit 1; \
		cd - > /dev/null; \
	done
	@echo "All tests completed!"

# Clean build artifacts
clean:
	rm -rf build
	@for package in {{packages}}; do \
		rm -rf packages/$package/build; \
	done

# Run full CI pipeline for all packages
ci: format-check build-all test-all