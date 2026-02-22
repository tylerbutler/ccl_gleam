# CCL Test Runner justfile

# === ALIASES ===
alias b := build
alias t := test
alias f := format
alias c := check
alias d := docs
alias cl := change

# Default recipe - show available commands
default:
    @just --list

# === DEPENDENCIES ===

# Install dependencies
deps:
    gleam deps download

# === BUILD ===

# Build the project
build:
    gleam build

# Build with warnings as errors
build-strict:
    gleam build --warnings-as-errors

# === TESTING ===

# Run unit tests
test:
    gleam test

# === CODE QUALITY ===

# Format code
format:
    gleam format src test

# Check formatting without modifying
format-check:
    gleam format --check src test

# Type check without building
check:
    gleam check

# === DOCUMENTATION ===

# Build documentation
docs:
    gleam docs build

# === CHANGELOG ===

# Create a new changelog entry
change:
    changie new

# Preview unreleased changelog
changelog-preview:
    changie batch auto --dry-run

# Generate CHANGELOG.md
changelog:
    changie merge

# === MAINTENANCE ===

# Clean build artifacts
clean:
    gleam clean

# === CI ===

# Run all CI checks (format, check, test, build)
ci: format-check check test build-strict

# Alias for PR checks
alias pr := ci

# Run extended checks for main branch
main: ci docs

# === CCL TEST RUNNER ===

# Run the test runner against ccl-test-data
run *ARGS:
    gleam run -- {{ ARGS }}

# Run tests with default config (parse-only)
run-tests DIR="../ccl-test-data/generated_tests/":
    gleam run -- run {{ DIR }}

# Run tests for specific functions
run-tests-with-functions DIR="../ccl-test-data/generated_tests/" FUNCTIONS="parse,print":
    gleam run -- run {{ DIR }} --functions {{ FUNCTIONS }}

# List test files with counts
list DIR="../ccl-test-data/generated_tests/":
    gleam run -- list {{ DIR }}

# Show test suite statistics
stats DIR="../ccl-test-data/generated_tests/":
    gleam run -- stats {{ DIR }}

# Launch interactive TUI viewer
view DIR="../ccl-test-data/generated_tests/":
    gleam run -- view {{ DIR }}

# Run the debug parser to check JSON parsing
debug-parse:
    gleam run -m debug_parse

# Build and run tests in one step
all: build test
