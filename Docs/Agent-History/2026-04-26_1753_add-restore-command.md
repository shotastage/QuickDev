# Implementation History

## Added/Changed Files

- `Sources/QuickDev/ArchiveTypes.swift`: Added restore inspection/result types shared between the archive restore service and the CLI.
- `Sources/QuickDev/ArchiveRestorer.swift`: Added archive inspection, manifest extraction, structure validation, and payload restoration logic for `.qda` archives.
- `Sources/CLI/Commands/RestoreCommand.swift`: Added the new `restore` CLI command with archive path resolution, default destination selection, dry-run output, and final restore messaging.
- `Sources/CLI/MainCLI.swift`: Registered `RestoreCommand` in the top-level CLI subcommand list.
- `Tests/QuickDevTests/ArchiveRestorerTests.swift`: Added round-trip restore and safety validation tests for unexpected archive entries and destination collisions.
- `Tests/QuickDevTests/RestoreCommandSupportTests.swift`: Added unit tests for archive path resolution and default/custom destination behavior.
- `Docs/CLI-Reference.md`: Documented restore usage, options, and behavior.
- `README.md`: Added restore to current capabilities and usage examples.
- `Docs/Roadmap.md`: Removed restore from the planned command list now that it is implemented.
- `CHANGELOG.md`: Recorded the new restore command in the latest release section.

## Implementation Summary

- Implemented a `restore` command as the archive counterpart for `.qda` files.
- The restore pipeline validates archive structure before extraction, reads `meta/archive.json`, rejects unexpected top-level entries, refuses destination collisions, and restores the payload into a fresh directory.
- The CLI defaults restores to `~/Developer/<project-name>`, supports `--destination` overrides and `--dry-run`, and prints embedded restore hints after inspection or restore.

## Key Functions

- `ArchiveRestorer.inspectArchive`: Lists archive entries, validates the allowed `payload/` and `meta/archive.json` layout, extracts and decodes the manifest, and returns payload metadata for preview flows.
- `ArchiveRestorer.restoreArchive`: Reuses archive inspection, creates a staging extraction area, restores the payload into the final destination, and returns a summary result for CLI output.
- `RestoreCommand.run`: Resolves the archive path, chooses the default or explicit restore destination, supports dry-run reporting, and prints user-facing restore summaries.
- `RestoreCommandSupport.resolveArchiveURL` and `buildRestoreDestinationPath`: Normalize user-supplied archive/destination paths and provide the default `~/Developer/<project-name>` restore location.

## Verification Steps

- `swift test`: Expected the full Swift test suite to pass, including the new restore tests.
- `swift run CLI --help`: Expected `restore` to appear in the registered subcommand list.
- `swift run CLI help restore`: Expected restore-specific arguments and options to render correctly.
- `swift run CLI restore <temp-archive>.qda --dry-run --destination <temp-destination>`: Expected manifest preview output and restore hints without extraction.
- `swift run CLI restore <temp-archive>.qda --destination <temp-destination>`: Expected successful extraction and restored payload files at the destination.

## Future Extension Points

- Add automatic post-restore execution of selected manifest restore hints behind an explicit confirmation or flag in `Sources/CLI/Commands/RestoreCommand.swift`.
- Extend archive validation to include checksums or signatures once manifest integrity metadata exists in `Sources/QuickDev/ArchiveTypes.swift` and `Sources/QuickDev/ArchiveRestorer.swift`.
- Refresh the cached project index automatically after restores that target `~/Developer` via `ProjectIndexCommandSupport` in `Sources/CLI/`.
