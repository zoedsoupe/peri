# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema. It provides flexible data validation with an expressive DSL, supporting complex nested data structures, custom validation functions, data generation capabilities, and Ecto integration.

## Development Commands

```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a single test file
mix test test/path/to/test_file.exs

# Run tests matching a pattern
mix test --only describe:"validation"

# Format code
mix format

# Check formatting without making changes
mix format --check-formatted

# Run Credo for static analysis
mix credo --strict

# Run Dialyzer for type checking (first run builds PLT cache)
mix dialyzer

# Generate documentation
mix docs

# Run benchmarks
mix run priv/benchs/simple.exs
mix run priv/benchs/complex.exs
```

## Architecture and Key Concepts

### Core Modules

- **`Peri`** (lib/peri.ex): Main module containing validation logic, DSL macros (`defschema`), and type definitions
- **`Peri.Parser`** (lib/peri/parser.ex): Manages validation state, including root data tracking for callbacks
- **`Peri.Error`** (lib/peri/error.ex): Error structure and formatting for validation failures
- **`Peri.Generatable`** (lib/peri/generatable.ex): Data generation based on schemas using StreamData
- **`Peri.Ecto`** (lib/peri/ecto.ex): Ecto changeset integration
- **`Peri.Ecto.Type.*`**: Custom Ecto types for database integration

### Validation Flow

1. **Entry Point**: `Peri.validate/2` accepts a schema and data
2. **Data Filtering**: `filter_data/2` processes input, preserving original key types (atom vs string)
3. **Schema Traversal**: `traverse_schema/3` iterates through schema fields
4. **Field Validation**: `validate_field/3` handles each field based on its type
5. **Nested Schemas**: For maps/lists with nested schemas, recursively validates with proper context

### Key Implementation Details

- **Key Atomization**: The library intelligently handles both atom and string keys. When looking up values, it checks atom keys first, then falls back to string versions.
- **List Validation**: Creates new parser contexts for each list element while preserving root data reference
- **Callback Context**: 2-arity callbacks receive `(current, root)` where current is the element being validated (useful in lists) and root is the entire data structure
- **Optional by Default**: All fields are optional unless wrapped with `{:required, type}`

### Type System

Basic types: `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:map`, `:pid`, `:any`

Complex types:
- `{:list, type}` - Lists of elements
- `{:map, type}` or `{:map, key_type, value_type}` - Maps with typed values
- `{:tuple, [types...]}` - Fixed-size tuples
- `{:enum, [values...]}` - Enumerated values
- `{:either, {type1, type2}}` - Union of two types
- `{:oneof, [types...]}` - Union of multiple types
- `{:cond, callback, true_type, false_type}` - Conditional validation
- `{:dependent, callback}` - Dynamic type determination

Constraints: `:gt`, `:gte`, `:lt`, `:lte`, `:in`, `:regex`

### Testing Patterns

- Test files mirror the lib structure (e.g., `lib/peri.ex` → `test/peri_test.exs`)
- Use `defschema` in test modules to create reusable test schemas
- Comprehensive edge case testing for each type
- Property-based testing with StreamData for generated data

## CI/CD Workflow

GitHub Actions runs three jobs:
1. **lint**: Checks formatting and runs Credo
2. **static-analysis**: Runs Dialyzer with cached PLTs
3. **test**: Runs the full test suite

All checks must pass before merging PRs.
