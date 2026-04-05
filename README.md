# QuickDev

QuickDev is an Apple Silicon macOS command-line tool for scanning and indexing local development projects under a single workspace root such as `~/Developer`.

The installed CLI command is `qd`. Today, QuickDev focuses on fast, read-only project discovery and metadata indexing. The longer-term goal is to help developers manage the full lifecycle of local projects: active work, archival, safe deletion, and eventual cleanup.

## Install

Build and install `qd` from source on an Apple Silicon Mac with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/shotastage/QuickDev/main/Tools/installer.sh | bash
```

The installer downloads the QuickDev source from GitHub, builds it locally with Swift, and installs `qd` to `$HOME/.local/bin` by default.

For version-pinned installs and custom install directories, see the Installation section below.

QuickDev currently supports Apple Silicon Macs only.

## Policies

- [AI and Agent Utilization Policy](Docs/AI-Agent-Policy.md)
- [Documentation Index](Docs/INDEX.md)

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

- An Apple Silicon macOS CLI exposed as `qd`
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

## Documentation

Detailed references have moved to `Docs/`.

- [Documentation Index](Docs/INDEX.md)
- [CLI Reference](Docs/CLI-Reference.md)
- [Data Model](Docs/Data-Model.md)
- [Architecture](Docs/Architecture.md)
- [Roadmap](Docs/Roadmap.md)

## Installation

### One-line install

Build and install `qd` from source with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/shotastage/QuickDev/main/Tools/installer.sh | bash
```

The installer downloads the QuickDev source from GitHub, builds `qd` locally with Swift, and installs it to `$HOME/.local/bin` by default.

Install a specific release tag:

```bash
curl -fsSL https://raw.githubusercontent.com/shotastage/QuickDev/main/Tools/installer.sh | bash -s -- --version v0.0.1
```

Install to a custom directory:

```bash
curl -fsSL https://raw.githubusercontent.com/shotastage/QuickDev/main/Tools/installer.sh | bash -s -- --install-dir "$HOME/.local/bin"
```

### Run from source

```bash
swift run CLI --help
swift run CLI scan
```

### Build a release binary locally

```bash
swift build -c release --product CLI
cp .build/release/CLI "$HOME/.local/bin/qd"
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

For detailed command examples, data model, architecture notes, and roadmap planning, use the docs index in `Docs/INDEX.md`.

## Requirements

- macOS
- Swift 6.3 or newer toolchain
- Xcode with Swift 6.3 support recommended for local development

## License

MIT. See `LICENSE`.
