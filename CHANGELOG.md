# Changelog

All notable changes to this project will be documented in this file.

## [0.5.1] - 2025-6-29

### Added

- Split out `validation_result` from validation type for reuse (#34)

## [0.5.0] - 2025-06-18

### Added

- **Validation Modes**: New permissive mode allows preserving fields not defined in the schema (#33)
  - Default mode remains `:strict` which filters out undefined fields
  - New `:permissive` mode preserves all input fields while still validating defined fields
  - Support for mode option in `defschema` macro: `defschema :name, schema, mode: :permissive`
  - Useful for API gateways, progressive validation, and middleware scenarios

### Fixed

- Fixed nested schemas in lists not having their keys atomized properly (#32)
  - String keys in nested schemas within lists are now correctly converted to atoms
  - Maintains consistent behavior with top-level schema validation

### Internal

- Added `CLAUDE.md` file for AI-assisted development guidance
- Enhanced `.formatter.exs` to export `defschema/3` for proper formatting

## [0.4.1] - 2025-06-18

### Changed

- **BREAKING**: Minimum Elixir version requirement is now 1.17 due to `Duration` struct usage introduced in 0.4.0
  - The `Duration` struct was introduced in Elixir 1.17
  - Previous `mix.exs` incorrectly specified `~> 1.16` compatibility

## [0.4.0] - 2025-10-06 [YANKED]

### Added

- **Ecto Integration**: New `Peri.to_changeset!/2` function to generate Ecto changesets from Peri schemas
  - Automatically generated `<name>_changeset/1` functions when defining schemas with `defschema` (when Ecto is loaded)
  - Support for all Peri types in Ecto changesets including nested schemas, custom types, and validations
  - Custom Ecto types: `Peri.Ecto.Type.PID`, `Peri.Ecto.Type.Atom`, `Peri.Ecto.Type.Any`, `Peri.Ecto.Type.Tuple`, `Peri.Ecto.Type.Either`, `Peri.Ecto.Type.OneOf`
  - Full support for embedded schemas with `:oneof`, `:either`, and nested map validations
  - Comprehensive validation rules are preserved when converting to changesets

- **New Types**:
  - `:duration` type for validating `%Duration{}` structs
  
- **JSON Support**: 
  - Added `Jason.Encoder` protocol implementation for `Peri.Error`
  - Support for encoding errors as JSON when Jason is available
  
- **Performance Benchmarks**:
  - Added benchmark suite comparing Peri validation with Ecto changeset generation
  - Benchmarks for both simple and complex schemas

### Changed

- Updated Elixir version requirement in development environment to 1.19.0-rc.0
- Updated nix flake configuration with elixir-overlay
- Improved error handling and JSON encoding for `Peri.Error`

### Internal

- Major refactoring of the core `Peri` module to support Ecto integration
- Added `Peri.Ecto` module for parsing Peri schemas into Ecto-compatible definitions
- Enhanced type system to support bidirectional conversion between Peri and Ecto types

## [0.3.3] - 2025-06-10

### Added

- Support for 2-arity callbacks in `:cond` and `:dependent` types (#28)
  - 1-arity callbacks receive the root data structure (backward compatible)
  - 2-arity callbacks receive `(current, root)` where:
    - `current` is the data at the current validation context (e.g., list element being validated)
    - `root` is the entire root data structure
  - This is especially useful when validating elements within lists, allowing callbacks to access the current element's data instead of the parent structure
  - MFA (Module, Function, Arguments) style callbacks also support 2-arity functions

## [0.3.1] - 2025-03-14

### Fixed

- Make `:either` behave consistently with `:oneof` for nested schemas (#21)

### Added

- New schema types for map and literal (#22)

## [0.2.11] - 2024-09-16

### Added

- ability to pass partial MFA (aka `{mod, fun}`) or complete MFA (aka `{mof, fun, args}`) to `:transform`, `:dependent` and `:default` directives

## [0.2.10] - 2024-09-16

### Added

- fixes for `0.2.10` [45300d3]
  - default values are also applied to nested schemas when the parent node is `nil`
  - all type schemas are treat as optional by default
  - allow types as valid schema definition
    - `:date`
    - `:time`
    - `:datetime`
    - `:naive_datetime`
    - `:pid`

## [0.2.8] - 2024-08-01

### Added

- handle structs as input data for schemas [859a0fd]
- support validate enumerable schemas on raw data structures (eg. `:list` type) [32aa540]

## [0.2.7] - 2024-07-28

### Added

- Support multiple dependencies for the `:dependent` type [1be99ef]
- `:cond` type receives "root data" and is treated as required by default [336316c]
- basic `Jason.Protocol` for `Peri.Error` (optional) [9031b1e]
- correctly pass "root data" to `:cond` and `:dependent` types [b79dfbd]
- allow usage of `:one_of` and `get_schema/1` [cb1b250]
- handle schemas definitions with string keys [266b5a2]

## [0.2.6] - 2024-06-27

### Added

- Data generation with based on `StreamData` provided as the `Peri.generate/1` function that receives a schema and returns a stream of generated data that matches this schema. [c85b972]

## [0.2.5] - 2024-06-22

### Added

-	Numeric and String Validations: Implemented new validation types for numeric and string data, including regex patterns, equality, inequality, range, and length validations. This allows for more granular and specific data validations. [9bb797e]

## [0.2.4] - 2024-06-21
- Implemented new type `{type, {:default, default}}`. [a569ecf, 821935f]
- Implemented new type `{type, {:transform, mapper}}`. [785179d]

## [0.2.3] - 2024-06-18

### Added
- Implemented schema validation, bang functions, and improved error inspection. [fc061f0]

### Fixed
- Improved error handling and inspecting. [f4d504b, afb054e]

## [0.2.2] - 2024-06-17

### Added
- Native support for keyword lists. [9f8aaef]
- `conforms?/1` function. [9a39ed8]

## [0.2.1] - 2024-06-16

### Added
- Continuous Integration (CI) setup. [16cf116]

### Fixed
- Corrected mix.exs file for hex package. [af5a744]

## [0.2.0] - 2024-06-15

### Added
- Enhanced error handling features. [f4d504b, afb054e]

### Fixed
- Documentation updates in README and Hex docs. [4fd48ce]

## [0.1.4] - 2024-06-10

### Added
- Support for `any`, `atom`, `oneof`, and `either` types. [6a225f4]

## [0.1.2] - 2024-06-05

### Added
- Removed unknown fields from schema validation. [3fa79d4]
- Allowed custom, composable, and recursive schemas. [fd1f593]

### Fixed
- Support for string map keys. [1b6edef]

## [0.1.1] - 2024-06-02

### Added
- Support for `tuple`, `lists`, `enum`, and custom types. [7766adc]

## [0.1.0] - 2024-06-01

### Added
- Initial version of Peri with basic schema validation functionalities. [7044ea7]

[0.5.0]: https://github.com/zoedsoupe/peri/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/zoedsoupe/peri/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/zoedsoupe/peri/compare/v0.3.3...v0.4.0
[0.3.3]: https://github.com/zoedsoupe/peri/compare/v0.3.1...v0.3.3
[0.3.1]: https://github.com/zoedsoupe/peri/compare/v0.2.11...v0.3.1
[0.2.11]: https://github.com/zoedsoupe/peri/compare/v0.2.10...v0.2.11
[0.2.10]: https://github.com/zoedsoupe/peri/compare/v0.2.8...v0.2.10
[0.2.8]: https://github.com/zoedsoupe/peri/compare/v0.2.7...v0.2.8
[0.2.7]: https://github.com/zoedsoupe/peri/compare/v0.2.6...v0.2.7
[0.2.6]: https://github.com/zoedsoupe/peri/compare/v0.2.5...v0.2.6
[0.2.5]: https://github.com/zoedsoupe/peri/compare/v0.2.4...v0.2.5
[0.2.4]: https://github.com/zoedsoupe/peri/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/zoedsoupe/peri/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/zoedsoupe/peri/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/zoedsoupe/peri/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/zoedsoupe/peri/compare/v0.1.4...v0.2.0
[0.1.4]: https://github.com/zoedsoupe/peri/compare/v0.1.2...v0.1.4
[0.1.2]: https://github.com/zoedsoupe/peri/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/zoedsoupe/peri/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zoedsoupe/peri/releases/tag/v0.1.0
