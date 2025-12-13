#!/usr/bin/env just --justfile

# Common aliases for faster development
alias b := build
alias t := test
alias tc := test-counts
alias c := check
alias f := format
alias pr := ci

# Default recipe - shows available commands
default:
    @just --list

# Check all packages
check:
	@just _check-ccl-types
	@just _check-ccl-core
	@just _check-ccl-test-loader
	@just _check-ccl

# Test all packages
test:
	@just _test-ccl-types
	@just _test-ccl-core
	@just _test-ccl-test-loader
	@just _test-ccl

# Test all packages with assertion counting
test-counts:
	@cd packages/ccl_test_loader && gleam run -m assertion_counting_demo

# Build all packages
build:
	@just _build-ccl-types
	@just _build-ccl-core
	@just _build-ccl-test-loader
	@just _build-ccl

# Format all packages
format:
	@just _format-ccl-types
	@just _format-ccl-core
	@just _format-ccl-test-loader
	@just _format-ccl

# Check formatting for all packages
format-check:
	@just _format-check-ccl-types
	@just _format-check-ccl-core
	@just _format-check-ccl-test-loader
	@just _format-check-ccl

# Run all quality checks
lint: check format-check

# Clean build artifacts
clean:
	@just _clean-root
	@just _clean-ccl-types
	@just _clean-ccl-core
	@just _clean-ccl-test-loader
	@just _clean-ccl

# Run full CI pipeline
ci: lint build test

# Private helper recipes for ccl_types package
_check-ccl-types:
	@cd packages/ccl_types && gleam check

_test-ccl-types:
	@cd packages/ccl_types && gleam test

_build-ccl-types:
	@cd packages/ccl_types && gleam build

_format-ccl-types:
	@cd packages/ccl_types && gleam format

_format-check-ccl-types:
	@cd packages/ccl_types && gleam format --check

_clean-ccl-types:
	@rm -rf packages/ccl_types/build

# Private helper recipes for ccl_core package
_check-ccl-core:
	@cd packages/ccl_core && gleam check

_test-ccl-core:
	@cd packages/ccl_core && gleam test

_build-ccl-core:
	@cd packages/ccl_core && gleam build

_format-ccl-core:
	@cd packages/ccl_core && gleam format

_format-check-ccl-core:
	@cd packages/ccl_core && gleam format --check

_clean-ccl-core:
	@rm -rf packages/ccl_core/build

# Private helper recipes for ccl_test_loader package
_check-ccl-test-loader:
	@cd packages/ccl_test_loader && gleam check

_test-ccl-test-loader:
	@cd packages/ccl_test_loader && gleam test

_build-ccl-test-loader:
	@cd packages/ccl_test_loader && gleam build

_format-ccl-test-loader:
	@cd packages/ccl_test_loader && gleam format

_format-check-ccl-test-loader:
	@cd packages/ccl_test_loader && gleam format --check

_clean-ccl-test-loader:
	@rm -rf packages/ccl_test_loader/build

# Private helper recipes for ccl package
_check-ccl:
	@cd packages/ccl && gleam check

_test-ccl:
	@cd packages/ccl && gleam test

_build-ccl:
	@cd packages/ccl && gleam build

_format-ccl:
	@cd packages/ccl && gleam format

_format-check-ccl:
	@cd packages/ccl && gleam format --check

_clean-ccl:
	@rm -rf packages/ccl/build

# Private helper recipe for root clean
_clean-root:
	@rm -rf build