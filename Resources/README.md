# Packaging Resources

This directory contains packaging templates for distributing QuickDev.

## Contents

- homebrew/quickdev.rb: Homebrew formula template for publishing qd.
- debian/: Debian packaging metadata templates for future Linux support.
- rpm/quickdev.spec: RPM spec template for future Linux support.

## Release Workflow (Current)

1. Build release artifacts with:
   ./Tools/build-package.sh
2. Upload dist/quickdev-<version>-darwin-arm64.tar.gz and .sha256 to a GitHub release.
3. Update Resources/homebrew/quickdev.rb with the release URL and SHA-256.

## Linux Packaging (Planned)

The Debian and RPM files are scaffolding for future Linux releases.
When Linux binaries become available, replace placeholder values and wire these
files into CI packaging jobs.
