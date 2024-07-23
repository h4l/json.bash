# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet.

## [0.3.0] — 2024-07-23

### BREAKING CHANGES

> [!NOTE]
>
> `json.bash` is version `0.x`, so the major version is not incremented.

- The `json.validate` function now sets and clears a bash trap for `SIGPIPE`
  when called. If something else in a bash script is also setting a trap for
  `SIGPIPE`, the trap will be cleared after validating JSON. (It's not practical
  to detect and restore existing `SIGPIPE` traps due to the performance cost of
  doing so.) ([#15](https://github.com/h4l/json.bash/pull/15))

### Fixed

- The JSON validation co-process exiting at startup could cause bash to exit
  with an unbound variable error, due to the special coproc `_PID` var not being
  set. Interaction with the validator co-process is now more robust to errors
  that can occur when it exits unexpectedly. For example, if the grep command is
  not compatible with the GNU grep flags we use.
  ([#15](https://github.com/h4l/json.bash/pull/15))

### Added

- The `JSON_BASH_GREP` environment variable can be set to a `:` delimited list
  of commands to use when starting the grep JSON validator co-process. It
  defaults to `ggrep:grep`, so systems with `ggrep` will use it first. (GNU grep
  is commonly `ggrep` when `grep` is not GNU grep.)
  ([#15](https://github.com/h4l/json.bash/pull/15))

### Changed

- Fixed broken link in README's manual install instructions
  (https://github.com/h4l/json.bash/pull/8)
- Added external packages list to the README
  (https://github.com/h4l/json.bash/pull/9)
  - We now have a package in the Arch User Repo thanks to
    [kseistrup](https://aur.archlinux.org/account/kseistrup)
- `--help` text uses `:json` instead of `:raw` in one of the examples
  (https://github.com/h4l/json.bash/pull/9)
- Updated `examples/jb-cli.sh` to use the current argument syntax — it was out
  of date.
- `json.bash` now has a copyright/license/url comment in at the top. This should
  make its origin clear when vendored into a downstream project as a dependency.

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
[0.3.0]: https://github.com/h4l/json.bash/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/h4l/json.bash/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/h4l/json.bash/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/h4l/json.bash/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/h4l/json.bash/compare/1aa11...v0.1.0
