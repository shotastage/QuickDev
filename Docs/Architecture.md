# QuickDev Architecture

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
