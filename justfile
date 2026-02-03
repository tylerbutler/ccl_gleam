# CCL Test Runner justfile

# Default recipe - show available commands
default:
    @just --list

# Install dependencies
deps:
    gleam deps download

# Build the project
build:
    gleam build

# Run unit tests
test:
    gleam test

# Format code
format:
    gleam format

# Check formatting without modifying
check-format:
    gleam format --check

# Type check without building
check:
    gleam check

# Clean build artifacts
clean:
    gleam clean

# Run the test runner against ccl-test-data
run *ARGS:
    gleam run -- {{ ARGS }}

# Run tests with default config (parse-only)
run-tests DIR="../ccl-test-data/generated_tests/":
    gleam run -- {{ DIR }}

# Run tests for specific functions
run-tests-with-functions DIR="../ccl-test-data/generated_tests/" FUNCTIONS="parse,print":
    gleam run -- {{ DIR }} --functions {{ FUNCTIONS }}

# Run the debug parser to check JSON parsing
debug-parse:
    gleam run -m debug_parse

# Build and run tests in one step
all: build test

# CI check - format, build, test
ci: check-format build test
