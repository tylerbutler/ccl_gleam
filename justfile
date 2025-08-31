#!/usr/bin/env just --justfile

# Common aliases for faster development
alias b := build
alias t := test
alias l := lint
alias f := fix
alias c := check

# Default recipe - shows available commands
default:
    @just --list


build *ARGS='':
    gleam build --warnings-as-errors {{ARGS}}

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

# Run full CI pipeline
ci: format-check check test
