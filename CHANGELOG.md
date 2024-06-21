# Changelog

All notable changes to this project will be documented in this file.

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

[0.2.3]: https://github.com/zoedsoupe/peri/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/zoedsoupe/peri/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/zoedsoupe/peri/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/zoedsoupe/peri/compare/v0.1.4...v0.2.0
[0.1.4]: https://github.com/zoedsoupe/peri/compare/v0.1.2...v0.1.4
[0.1.2]: https://github.com/zoedsoupe/peri/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/zoedsoupe/peri/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zoedsoupe/peri/releases/tag/v0.1.0
