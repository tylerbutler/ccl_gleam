# ccl_gleam monorepo justfile

ccl_dir := "packages/ccl"
runner_dir := "packages/ccl_test_runner"
codegen_dir := "packages/ccl_codegen"

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

# Install dependencies for all packages
deps:
    cd {{ ccl_dir }} && gleam deps download
    cd {{ runner_dir }} && gleam deps download
    cd {{ codegen_dir }} && gleam deps download

# === BUILD ===

# Build all packages
build:
    cd {{ ccl_dir }} && gleam build
    cd {{ runner_dir }} && gleam build
    cd {{ codegen_dir }} && gleam build

# Build with warnings as errors
build-strict:
    cd {{ ccl_dir }} && gleam build --warnings-as-errors
    cd {{ runner_dir }} && gleam build --warnings-as-errors
    cd {{ codegen_dir }} && gleam build --warnings-as-errors

# Build only the CCL library
build-ccl:
    cd {{ ccl_dir }} && gleam build

# Build only the test runner
build-runner:
    cd {{ runner_dir }} && gleam build

# Build only the codegen
build-codegen:
    cd {{ codegen_dir }} && gleam build

# === TESTING ===

# Run all tests
test:
    cd {{ ccl_dir }} && gleam test
    cd {{ runner_dir }} && gleam test
    cd {{ codegen_dir }} && gleam test

# Run CCL library tests only
test-ccl:
    cd {{ ccl_dir }} && gleam test

# Run test runner tests only
test-runner:
    cd {{ runner_dir }} && gleam test

# Run codegen tests only
test-codegen:
    cd {{ codegen_dir }} && gleam test

# === CODE QUALITY ===

# Format all code
format:
    cd {{ ccl_dir }} && gleam format src test
    cd {{ runner_dir }} && gleam format src test
    cd {{ codegen_dir }} && gleam format src test

# Check formatting without modifying
format-check:
    cd {{ ccl_dir }} && gleam format --check src test
    cd {{ runner_dir }} && gleam format --check src test
    cd {{ codegen_dir }} && gleam format --check src test

# Type check all packages
check:
    cd {{ ccl_dir }} && gleam check
    cd {{ runner_dir }} && gleam check
    cd {{ codegen_dir }} && gleam check

# === DOCUMENTATION ===

# Build documentation
docs:
    cd {{ ccl_dir }} && gleam docs build
    cd {{ runner_dir }} && gleam docs build
    cd {{ codegen_dir }} && gleam docs build

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
    cd {{ ccl_dir }} && gleam clean
    cd {{ runner_dir }} && gleam clean
    cd {{ codegen_dir }} && gleam clean

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
    cd {{ runner_dir }} && gleam run -- {{ ARGS }}

# Run tests with default config (parse-only)
run-tests DIR="./ccl-test-data/":
    cd {{ runner_dir }} && gleam run -- run {{ DIR }}

# Run tests for specific functions
run-tests-with-functions DIR="./ccl-test-data/" FUNCTIONS="parse,print":
    cd {{ runner_dir }} && gleam run -- run {{ DIR }} --functions {{ FUNCTIONS }}

# List test files with counts
list DIR="./ccl-test-data/":
    cd {{ runner_dir }} && gleam run -- list {{ DIR }}

# Show test suite statistics
stats DIR="./ccl-test-data/":
    cd {{ runner_dir }} && gleam run -- stats {{ DIR }}

# Launch interactive TUI viewer
view DIR="./ccl-test-data/":
    cd {{ runner_dir }} && gleam run -- view {{ DIR }}

# Download latest CCL test data from GitHub releases
download-tests:
    cd {{ runner_dir }} && npx ccl-test-runner-ts -f -o ./ccl-test-data

# Build and run tests in one step
all: build test

# === CCL CODEGEN ===

# Generate a decoder for a type in a Gleam source file
generate FILE TYPE:
    cd {{ codegen_dir }} && gleam run -- generate {{ FILE }} {{ TYPE }}
