# QuickDev Data Model

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
