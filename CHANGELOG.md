# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]
- Placeholder for upcoming changes. Watch this space.

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
