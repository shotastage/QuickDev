# QuickDev Roadmap

The current codebase implements scanning and indexing. The following capabilities are planned next.

## Core lifecycle commands

- `archive` to create recoverable project archives
- `restore` to restore archived projects
- `trash` to move projects into a protected deletion workflow
- `purge` to permanently remove projects after explicit confirmation

## Metadata improvements

- Project status transitions such as `active`, `archived`, and `trashed`
- Project size calculation
- Additional language and toolchain detectors
- Better incremental scan behavior

## Security and integrity

- Manifest-based archives
- SHA-256 verification for archive contents
- Safe restore validation
- Optional signing support

## Developer ergonomics

- Richer filtering and listing output
- Machine-friendly JSON workflows across more commands
- More detailed Git summaries
- Better reporting for large workspace roots

## Non-goals for now

QuickDev is intentionally focused. These are out of scope for the near term:

- Cloud backup
- Remote synchronization
- Cross-platform support beyond macOS
- A GUI application
