# QuickDev CLI Reference

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

### Open a project in Visual Studio Code

`qd open` resolves a project name from the saved index and opens that directory in Visual Studio Code.

```bash
qd open Wonderway
```

If no compatible index exists yet, QuickDev scans first, saves the index, and then opens the project.

Use `--root` when you want to resolve names against a specific workspace root:

```bash
qd open Wonderway --root ~/Developer
```

## Command Reference

### `qd scan`

Discover projects under a development root and write the resulting metadata index.

Options:

- `--root <path>`: Root directory to scan. Defaults to `~/Developer`.
- `--json`: Print the complete index as JSON instead of a summary table.

Because `scan` is currently the default subcommand, invoking `qd` with no subcommand will run the same workflow.

### `qd list`

Display the saved project index without rescanning when possible.

Options:

- `--root <path>`: Require the saved index to match this root. If it does not exist yet, QuickDev scans this root and saves a fresh index.
- `--json`: Print the complete index as JSON instead of a summary table.

### `qd open`

Open a project directory from the saved index in Visual Studio Code.

Arguments:

- `<project-name>`: Directory name shown in `qd list`.

Options:

- `--root <path>`: Require the saved index to match this root. If it does not exist yet, QuickDev scans this root, saves a fresh index, and then resolves the project name.
