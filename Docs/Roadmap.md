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

## Platform strategy

- Linux support is planned for a future phase after the macOS workflow matures.
- Initial Linux support will focus on packaging and CLI compatibility (`deb` and `rpm`).
- Native Windows support is not planned.
- On Windows, the recommended path is to use QuickDev through Linux on WSL.

## Non-goals for now

QuickDev is intentionally focused. These are out of scope for the near term:

- Cloud backup
- Remote synchronization
- Native Windows support
- A GUI application
