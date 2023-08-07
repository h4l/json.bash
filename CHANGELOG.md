# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] — 2023-08-07

No functional changes, `0.2.1` wasn't published because of a cherry-picking
fail.

## [0.2.1] — 2023-08-07

No functional changes, `0.2.0` wasn't published because of a CI fail.

## [0.2.0] — 2023-08-07

### Added

- Revised argument syntax to support several new features
- Variable-length object values with `example:{}=a=1,b=2`
- Splat `...` operator — merge arrays/objects with `...=a=1,b=2`
- Arguments now set attributes via `:/example=foo/`
- JSON input format for arrays and objects with `[:json]` / `{:json}`
  - Allows merging JSON documents into properties or the host with `...`
- Missing/empty value handling
  - Missing files / unset variables can be treated as empty inputs using `~`
    flag
  - Arguments with empty inputs can substitute default values using `?` flag
  - Arguments with empty inputs can be omitted using `??` flag
  - Arguments can enforce non-empty inputs using `+` flag
- Alpine linux is supported
- Container image `ghcr.io/h4l/json.bash/jb`
- OS packages
  - Currently meta-published via a container image that can build many package
    formats: `ghcr.io/h4l/json.bash/pkg`

### Fixed

- Validator coprocess no longer closes process substitution file descriptors
  when starting
- Validator coprocess no longer times out sporadically when reading validation
  results
- Validator accepts strings with Unicode codepoints > 255

### Changed

- Defining defaults uses full argument syntax, rather than key-value attributes

## [0.1.0] — 2023-07-14

Initial release.

[unreleased]: https://github.com/h4l/json.bash/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/h4l/json.bash/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/h4l/json.bash/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/h4l/json.bash/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/h4l/json.bash/compare/1aa11...v0.1.0
