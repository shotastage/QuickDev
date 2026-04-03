# QuickDev Agent Guide

## Project Overview

QuickDev is a Swift Package Manager repository with two main targets:

- `QuickDev`: library target under `Sources/QuickDev`
- `CLI`: executable target under `Sources/CLI`, exposed as the `qd` command

The CLI is intended for macOS. `MainCLI.swift` uses a macOS-only entry point and a non-macOS fallback that must continue to compile cleanly.

## Repository Layout

- `Package.swift`: package manifest, Swift 6.3, `swift-argument-parser` dependency
- `Sources/CLI/MainCLI.swift`: top-level `ParsableCommand` and subcommand registration
- `Sources/CLI/Commands/`: individual CLI subcommands
- `Sources/CLI/Shell.swift`: process execution helpers
- `Sources/CLI/CommandProcedure.swift`: shared command procedure protocols
- `Sources/QuickDev/QuickDev.swift`: library surface
- `Tests/QuickDevTests/`: Swift Testing test suite

## Standard Commands

Run commands from the repository root.

- Build package: `swift build`
- Run tests: `swift test`
- Inspect CLI wiring: `swift run CLI --help`
- Run default CLI behavior: `swift run CLI`

After changing CLI parsing, subcommand registration, or shell execution, run both `swift test` and the relevant `swift run CLI ...` command.

## Implementation Rules

- Keep changes focused and avoid unrelated refactors.
- Follow the existing Swift style and keep public APIs stable unless the task requires a breaking change.
- Register every new `ParsableCommand` in `MainCLI.configuration.subcommands`.
- Prefer small, testable helpers over putting all logic directly in `ParsableCommand.run()`.
- Preserve platform guards around CLI entry points so the package still builds on unsupported platforms.

## Adding CLI Commands

- Add each new command as its own file under `Sources/CLI/Commands/`.
- Match the type name and file name to the command intent so command discovery stays obvious.
- Keep `ParsableCommand` types focused on argument parsing, validation, and orchestration.
- Move reusable or stateful behavior into helpers or procedure types instead of growing `run()` bodies.
- Give every command a clear `abstract` string so `swift run CLI --help` remains useful.
- Register every command in `MainCLI.configuration.subcommands` and only change `defaultSubcommand` when the task explicitly requires a new default flow.
- Prefer explicit `@Argument`, `@Option`, and `@Flag` definitions over manually parsing raw argument arrays.
- When a command uses external tooling, inspect `ShellResult.status`, `stdout`, and `stderr` and surface actionable failures instead of swallowing errors.
- Avoid placeholder-style failure messages; print or throw errors that explain which executable failed and why.
- Keep command output deterministic when practical so help text, tests, and CLI behavior are easy to verify.

### CLI Validation Checklist

- Run `swift run CLI --help` after adding or wiring a command.
- Run `swift run CLI help <subcommand>` for any new subcommand with custom options or arguments.
- Run the new command on its expected success path.
- If the command wraps shell execution, also exercise at least one failure path.
- Add or update tests when command behavior changes in a way that can be covered without full end-to-end process execution.

## Shell Execution Rules

- Prefer `Shell.run(_:arguments:currentDirectoryURL:environment:)` for external commands.
- Pass the executable and arguments separately. Do not pass a full shell command string to `Shell.run`.
- Use `Shell.runInShell(_:)` only when shell features are actually required, such as pipes, redirects, globbing, or compound shell expressions.
- Keep command execution safe by avoiding unnecessary shell interpolation.

Example:

- Preferred: `try Shell.run("echo", arguments: ["Hello, World!"])`
- Avoid: `try Shell.run("echo Hello, World!")`

## Testing Expectations

- Add or update tests in `Tests/QuickDevTests` when behavior changes.
- Use Swift Testing (`import Testing`) rather than XCTest unless the repository adopts a different test framework later.
- For CLI changes, extract logic into helpers when needed so behavior can be tested without relying only on end-to-end command execution.

## Agent Guidance

- Treat this repository as early-stage: prioritize correctness, command wiring, and safe process execution over abstraction-heavy design.
- If a task requires a new dependency, keep the addition minimal and update `Package.swift` carefully.
- When fixing command execution code, prefer the root cause over workaround string parsing.
