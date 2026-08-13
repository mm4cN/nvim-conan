# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]
- Placeholder for upcoming changes. Watch this space.

## [3.0.0] - 2026-08-13
### Breaking Changes
- Config file renamed from `.nvim-conan.json` to `conan-config.json`. Existing config files must be renamed manually.
- Plugin entry point ported from `plugin/conan.vim` to `plugin/conan.lua`.

### Added
- Config is now also discovered in `.vscode/conan-config.json`, allowing teams to co-locate it with other VS Code workspace settings. If either location contains a config, the setup wizard is skipped.
- Guard in `setup()` prevents double-initialisation when plugin managers call `setup()` explicitly alongside the auto-call from the plugin entry point.

## [2.0.0] - 2026-07-10
### Added
- `:checkhealth conan` to verify Neovim, Conan, and Telescope requirements.
- Built-in Vim help with generated helptags for `:help nvim-conan`.

### Changed
- Neovim requirement raised to 0.12 or higher.
- Conan must now be installed manually and available on your `PATH`.

### Removed
- Automatic Conan installation via `pip`.

## [1.5.3] - 2026-06-10
### Modified: Terminal behavior changed from bloated code screen. Opening new buffer instead.

## [1.4.0] - 2026-02-21
### Added: support for conf specification which might be useful to skip tests

## [1.3.1] - 2025-12-04
### Fixed: backwards compatibility issue

## [1.3.0] - 2025-
### Added: support for recipe selection

## [1.2.0] - 2025-08-21
### Added
- Floating terminal supports additional options.
- Floating terminal shows the executed command as its window title.

### Changed
- Floating terminal is now read-only and cannot be edited.
- Terminal window will not close on keypress if the command fails.

### Other
- Bumped version.
- Version 1.1.0 was skipped due to a mistake in the versioning process.

## [1.0.0] - 2025-04-14
### Added
- `:Conan install` — installs dependencies using the default profile.
- `:Conan build` — builds the project using Conan profiles.
- `:Conan lock` — creates or updates a Conan lockfile.
- `:Conan search` — searches locally cached packages.
- `:Conan create` — packages the current recipe.
- `:Conan export` — exports a Conan recipe.
- `:Conan export_package` — exports prebuilt package artifacts.
- `:Conan upload` — interactive upload with Telescope support.
  - Telescope picker for remote selection via `conan remote list`.
  - Telescope picker for selecting local references from cache via `conan list --format=json`.

### Changed
- Improved setup to auto-create config files only if missing.
- Version compatibility check added to config.

### Requirements
- Now depends on [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for upload functionality.

## [0.1.0] - 2025-04-10
### Added
- Project initialized.
- Changelog scaffolded.
