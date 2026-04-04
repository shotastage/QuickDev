# QuickDev

QuickDev is a macOS-first command-line tool for scanning and indexing local development projects under a single workspace root such as `~/Developer`.

The installed CLI command is `qd`. Today, QuickDev focuses on fast, read-only project discovery and metadata indexing. The longer-term goal is to help developers manage the full lifecycle of local projects: active work, archival, safe deletion, and eventual cleanup.

## Why QuickDev?

If you have been building software for years, your development directory probably contains a mix of active apps, prototypes, abandoned experiments, client work, and historical repositories.

Standard tools such as `ls` or Finder can show what exists, but they do not answer the operational questions that matter:

- Which folders are real projects?
- Which ones are Git repositories?
- Which projects have not changed in a long time?
- Which ones should be archived instead of deleted?
- Which ones are safe to clean up later?

QuickDev starts by turning a loose directory tree into structured project metadata that other lifecycle workflows can build on.

## Current Status

QuickDev is early-stage. The current release includes:

- A macOS CLI exposed as `qd`
- Read-only project scanning with `scan`
- Cached index inspection with `list`
- Project type detection for common development stacks
- Git repository inspection for origin URL and dirty-state metadata
- JSON index persistence to a local cache directory
- Human-readable table output or full JSON output

The broader lifecycle features described below are planned, but not yet implemented in the CLI.

## Goals

QuickDev is designed around a few operating principles:

- Safe by default
- Read-only scanning first
- Explicit workflows for destructive actions
- Structured metadata over ad hoc shell scripts
- Deterministic, inspectable output
- Developer-first ergonomics

## What It Detects

QuickDev currently considers a directory a project when it contains one or more of the following markers:

- `.git`
- `Package.swift`
- `package.json`
- `go.mod`
- `Cargo.toml`
- `pom.xml`
- `build.gradle` or `build.gradle.kts`
- `*.xcodeproj`
- `*.xcworkspace`

Detected project types currently include:

- Swift packages
- Node.js packages
- Go modules
- Rust crates
- Gradle projects
- Maven projects
- Xcode projects
- Git repositories

During scanning, QuickDev skips common heavy or generated directories such as `.git`, `node_modules`, `.build`, `DerivedData`, `dist`, `build`, `target`, `.next`, `.turbo`, `Pods`, `.gradle`, and Python virtual-environment folders.

The current scanner looks up to two directory levels below the selected root. That keeps scans predictable and fast while the indexing model is still evolving.

## Installation

### Run from source

```bash
swift run CLI --help
swift run CLI scan
```

### Build a release binary locally

```bash
swift build -c release --product CLI
cp .build/release/CLI /usr/local/bin/qd
```

### Build a distributable archive

The repository includes a packaging script that builds the release binary, runs tests by default, and emits a `.tar.gz` archive plus a SHA-256 checksum file:

```bash
./Tools/build-package.sh
```

Artifacts are written to `./dist`.

## Usage

### Scan the default development root

By default, `qd scan` scans `~/Developer`.

```bash
qd scan
```

If you are running from source instead of an installed binary:

```bash
swift run CLI scan
```

Example output:

```text
Scanned root: /Users/yourname/Developer
Projects found: 3
Saved index: /Users/yourname/.devctl/projects.json

NAME        TYPE                        MODIFIED
MagicCloud  swiftPackage,gitRepository  2026-04-04T10:15:00Z
Wonderway   nodePackage,gitRepository   2026-04-02T08:41:12Z
OldTools    gitRepository               2025-11-19T21:03:55Z
```

### Scan a custom root directory

```bash
qd scan --root ~/Work
```

Relative paths are resolved against the current working directory.

### Print the full index as JSON

```bash
qd scan --json
```

### Force a full scan

```bash
qd scan --force
```

The current implementation always performs a scan; `--force` exists to make scan intent explicit and to support future cache-aware behavior.

### List the current index without rescanning

```bash
qd list
```

`qd list` reads the saved index immediately when one is available. If no compatible index exists yet, it performs a scan, saves the result, and then prints it.

To require a cached index for a specific root and rescan only when needed:

```bash
qd list --root ~/Work
```

For machine-readable output:

```bash
qd list --json
```

## Index Storage

QuickDev persists scan output locally so other commands can build on a stable project index.

Current storage layout:

```text
~/.devctl/
├── projects.json
└── scan-state.json
```

Notes:

- The cache directory is currently `~/.devctl/`.
- That name reflects the tool's earlier draft naming and may be renamed in a future release.
- The directory is created with restrictive permissions.

## JSON Model

Each scan writes a `ProjectIndex` that includes:

- Index version
- Scanned root path
- Scan timestamp
- A list of discovered projects

Each project record currently stores:

- Project name
- Absolute path
- Path relative to the scan root
- Last modification timestamp
- Detected project types
- Whether the directory is a Git repository
- Git remote URL when available
- Whether the repository has uncommitted changes when detectable
- Primary language inferred from detected project type
- Lifecycle status, currently defaulting to `active`

## Command Reference

### `qd scan`

Discover projects under a development root and write the resulting metadata index.

Options:

- `--root <path>`: Root directory to scan. Defaults to `~/Developer`.
- `--json`: Print the complete index as JSON instead of a summary table.
- `--force`: Ignore future cache optimizations and perform a full scan.

Because `scan` is currently the default subcommand, invoking `qd` with no subcommand will run the same workflow.

### `qd list`

Display the saved project index without rescanning when possible.

Options:

- `--root <path>`: Require the saved index to match this root. If it does not exist yet, QuickDev scans this root and saves a fresh index.
- `--json`: Print the complete index as JSON instead of a summary table.

## Architecture

The repository is organized as a Swift Package with three primary targets:

- `QuickDev`: core scanning and indexing logic
- `SwiftCLIKit`: shared CLI support utilities
- `CLI`: the executable target that exposes the `qd` command

High-level structure:

```text
Sources/
├── CLI/
│   ├── Commands/
│   │   ├── ListCommand.swift
│   │   └── ScanCommand.swift
│   ├── MainCLI.swift
│   ├── CommandProcedure.swift
│   ├── ProjectIndexCommandSupport.swift
│   └── Shell.swift
├── QuickDev/
│   ├── GitInspector.swift
│   ├── ProjectClassifier.swift
│   ├── ProjectIndexStore.swift
│   ├── ProjectScanner.swift
│   └── QuickDev.swift
└── SwiftCLIKit/
    └── Progress.swift
```

## Development

Build the package:

```bash
swift build
```

Run the test suite:

```bash
swift test
```

Inspect CLI wiring:

```bash
swift run CLI --help
```

Run the default command flow:

```bash
swift run CLI
```

## Roadmap

The current codebase implements scanning and indexing. The following capabilities are planned next:

### Core lifecycle commands

- `archive` to create recoverable project archives
- `restore` to restore archived projects
- `trash` to move projects into a protected deletion workflow
- `purge` to permanently remove projects after explicit confirmation

### Metadata improvements

- Project status transitions such as `active`, `archived`, and `trashed`
- Project size calculation
- Additional language and toolchain detectors
- Better incremental scan behavior

### Security and integrity

- Manifest-based archives
- SHA-256 verification for archive contents
- Safe restore validation
- Optional signing support

### Developer ergonomics

- Richer filtering and listing output
- Machine-friendly JSON workflows across more commands
- More detailed Git summaries
- Better reporting for large workspace roots

## Non-Goals For Now

QuickDev is intentionally focused. These are out of scope for the near term:

- Cloud backup
- Remote synchronization
- Cross-platform support beyond macOS
- A GUI application

## Requirements

- macOS
- Swift 6.3 or newer toolchain
- Xcode with Swift 6.3 support recommended for local development

## License

MIT. See `LICENSE`.
