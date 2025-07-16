# Changelog

All notable changes to this project will be documented in this file.

## [0.6.0](https://github.com/zoedsoupe/peri/compare/v0.5.1...v0.6.0) (2025-07-16)


### Features

* `:schema` validator that can accept additional keys ([#37](https://github.com/zoedsoupe/peri/issues/37)) ([098be96](https://github.com/zoedsoupe/peri/commit/098be96a106671119bc7ea83d6fe9099a2319c36))
* add ci ([16cf116](https://github.com/zoedsoupe/peri/commit/16cf116b6e89e1d06c65ac15e26428475b305c44))
* add MFA support for transform, default and dependent directives ([8928e59](https://github.com/zoedsoupe/peri/commit/8928e59d68a5183f415caa4537ce2d16fb7c5281))
* add typespecs ([802e9f6](https://github.com/zoedsoupe/peri/commit/802e9f66390991dbf119046ab14708d89f02b16c))
* basic jason protocol support ([9031b1e](https://github.com/zoedsoupe/peri/commit/9031b1e42bea82c10e081646f18369c8dca6434a))
* cond type receives whole data and should be treated as required ([336316c](https://github.com/zoedsoupe/peri/commit/336316c3b9ab2dc4cc79ffaa51333d9a5c8742e9))
* data generation ([c85b972](https://github.com/zoedsoupe/peri/commit/c85b9720e972ea50e6caec0d8a30d67301b7ce97))
* data generations ([ecc2d2c](https://github.com/zoedsoupe/peri/commit/ecc2d2ca07147fd1d2c9262ba9f7de7ee1f0f02f))
* default values type ([821935f](https://github.com/zoedsoupe/peri/commit/821935f6198531985a752d9582e6abb55e8f844e))
* ecto integration ([#18](https://github.com/zoedsoupe/peri/issues/18)) ([8d3fe0d](https://github.com/zoedsoupe/peri/commit/8d3fe0d0eb0cef328ab550ecb15dad252c692ecd))
* handle structs as data ([#9](https://github.com/zoedsoupe/peri/issues/9)) ([859a0fd](https://github.com/zoedsoupe/peri/commit/859a0fdff9781f93bab913095e8ef6c2ec446256))
* implement schema validation, bang functions and improve error inspecting ([fc061f0](https://github.com/zoedsoupe/peri/commit/fc061f055fbb93ccce75201f3c6fc19579043d0f))
* improve error handling ([f4d504b](https://github.com/zoedsoupe/peri/commit/f4d504b3ca3f4c24c21512e4a59fd4d60a550d5b))
* multiple field dependencies dependent type ([1be99ef](https://github.com/zoedsoupe/peri/commit/1be99ef5abc1128643a2a8b50be750bb28ce7622))
* multiple validator options ([#35](https://github.com/zoedsoupe/peri/issues/35)) ([2c5ec2f](https://github.com/zoedsoupe/peri/commit/2c5ec2fccdb90663372f90fe6d21ec9ce9f48133))
* new schema types for map and literal ([#22](https://github.com/zoedsoupe/peri/issues/22)) ([feaf2c7](https://github.com/zoedsoupe/peri/commit/feaf2c7cecee6f03e825f2cd2c0340049e3ac80f))
* pass current elem in dependent/cond valdiations ([#28](https://github.com/zoedsoupe/peri/issues/28)) ([324b6f4](https://github.com/zoedsoupe/peri/commit/324b6f44577fe22ec74b80b9e068edf6b765793c))
* pass root data to the dependet and cond types ([b79dfbd](https://github.com/zoedsoupe/peri/commit/b79dfbd0b1ca18a74cc283c620e6c85b7abd5a8e))
* permissive schema ([#33](https://github.com/zoedsoupe/peri/issues/33)) ([3b4b137](https://github.com/zoedsoupe/peri/commit/3b4b1372d1ec00d9b38959549995d6654786e9a5))
* split out `validation_result` from `validation` type for reuse ([#34](https://github.com/zoedsoupe/peri/issues/34)) ([b3bd773](https://github.com/zoedsoupe/peri/commit/b3bd77324398e3415345820f16877d3d77cc50f2))
* transform type ([848eea7](https://github.com/zoedsoupe/peri/commit/848eea72b1717345d32ffce69790381621c5337c))
* use Peri.Parser to manage schema parsing state ([68fa43f](https://github.com/zoedsoupe/peri/commit/68fa43f776182ce747644fb29166b05c52b517f9))


### Bug Fixes

* correctly handle multiple struct fields as input data ([3cfe428](https://github.com/zoedsoupe/peri/commit/3cfe4282bfd6cde105b6f7b15e68a49567047772))
* credo warnings ([b0c906c](https://github.com/zoedsoupe/peri/commit/b0c906c1e8a14e19a429d7c81d6dd97acde477e7))
* dependent validation behavior ([#26](https://github.com/zoedsoupe/peri/issues/26)) ([e815b20](https://github.com/zoedsoupe/peri/commit/e815b200a09f9424e2d2317569b7cf6be4c180de))
* do not cast string/atom enum values ([1d11647](https://github.com/zoedsoupe/peri/commit/1d11647b2f6c9eae2edaf98f38b62c0131825c6b))
* do not fetch peri parser on raw data schemas ([#10](https://github.com/zoedsoupe/peri/issues/10)) ([32aa540](https://github.com/zoedsoupe/peri/commit/32aa54029f81f90b91e18e04f735db5f7022dae8))
* do not raise on schemas with string keys ([#4](https://github.com/zoedsoupe/peri/issues/4)) ([266b5a2](https://github.com/zoedsoupe/peri/commit/266b5a27f9278578b92cf8cdc0f95a19cda2d08b))
* make :either behave consistently with :oneof for nested ([#21](https://github.com/zoedsoupe/peri/issues/21)) ([d494847](https://github.com/zoedsoupe/peri/commit/d49484746ff8f8c022f03917de5a9004b4234608))
* nested schema on lists filter data and respect schema definition ([#32](https://github.com/zoedsoupe/peri/issues/32)) ([792fc9c](https://github.com/zoedsoupe/peri/commit/792fc9ca16a0810a1683d8c22e3aeaa60b1bb3e9))
* some corrections for 0.2.10 ([b212bc1](https://github.com/zoedsoupe/peri/commit/b212bc1982f74f779439a01ad0deb1ba8cf29afb))
* typos ([#25](https://github.com/zoedsoupe/peri/issues/25)) ([2e9782d](https://github.com/zoedsoupe/peri/commit/2e9782d2d1ec1c4c27905335140ea01469f972e9))

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
