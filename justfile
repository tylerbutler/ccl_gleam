# ccl_gleam monorepo justfile

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

# Install dependencies for all packages and download test data
deps: update-test-data
    gleam deps download
    cd {{ runner_dir }} && gleam deps download
    cd {{ codegen_dir }} && gleam deps download

# === BUILD ===

# Build all packages
build:
    gleam build
    cd {{ runner_dir }} && gleam build
    cd {{ codegen_dir }} && gleam build

# Build with warnings as errors
build-strict:
    gleam build --warnings-as-errors
    cd {{ runner_dir }} && gleam build --warnings-as-errors
    cd {{ codegen_dir }} && gleam build --warnings-as-errors

# Build only the CCL library
build-ccl:
    gleam build

# Build only the test runner
build-runner:
    cd {{ runner_dir }} && gleam build

# Build only the codegen
build-codegen:
    cd {{ codegen_dir }} && gleam build

# === TESTING ===

# Run all tests
test:
    gleam test
    cd {{ runner_dir }} && gleam test
    cd {{ codegen_dir }} && gleam test

# Run CCL library tests only
test-ccl:
    gleam test

# Run test runner tests only
test-runner:
    cd {{ runner_dir }} && gleam test

# Run codegen tests only
test-codegen:
    cd {{ codegen_dir }} && gleam test

# === CODE QUALITY ===

# Format all code
format:
    gleam format src test
    cd {{ runner_dir }} && gleam format src test
    cd {{ codegen_dir }} && gleam format src test

# Check formatting without modifying
format-check:
    gleam format --check src test
    cd {{ runner_dir }} && gleam format --check src test
    cd {{ codegen_dir }} && gleam format --check src test

# Type check all packages
check:
    gleam check
    cd {{ runner_dir }} && gleam check
    cd {{ codegen_dir }} && gleam check

# === DOCUMENTATION ===

# Build documentation
docs:
    gleam docs build
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
    gleam clean
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
update-test-data:
    cd {{ runner_dir }} && npx ccl-test-runner-ts -o=./ccl-test-data

# Build and run tests in one step
all: build test

# === CCL CODEGEN ===

# Generate a decoder for a type in a Gleam source file
generate FILE TYPE:
    cd {{ codegen_dir }} && gleam run -- generate {{ FILE }} {{ TYPE }}
