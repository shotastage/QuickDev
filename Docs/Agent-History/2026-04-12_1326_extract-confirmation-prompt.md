# Implementation History

## Added/Changed Files

- `Sources/SwiftCLIKit/ConfirmationPrompt.swift`: Added a shared yes/no confirmation helper for interactive CLI prompts.
- `Package.swift`: Linked the CLI target against `SwiftCLIKit` so shared prompt utilities can be reused from commands.
- `Sources/CLI/Commands/TransferCommand.swift`: Replaced the command-local confirmation loop with the shared prompt helper and removed transfer-specific parsing.
- `Sources/CLI/Commands/SelfUpdateCommand.swift`: Replaced the command-local yes/no check with the shared prompt helper.
- `Tests/QuickDevTests/TransferCommandSupportTests.swift`: Removed the transfer-specific confirmation parsing test after moving that behavior into `SwiftCLIKit`.
- `Tests/QuickDevTests/ConfirmationPromptTests.swift`: Added tests for shared confirmation parsing, retry behavior, and EOF/default handling.

## Implementation Summary

- Extracted the repeated yes/no parsing and retry loop into `SwiftCLIKit` so CLI commands use one consistent confirmation flow.
- Kept command-specific explanatory output in each command and limited the shared helper to prompt rendering, parsing, and retry/default behavior.

## Key Functions

- `ConfirmationPrompt.parse`: Normalizes terminal input and maps yes/no responses, including configurable empty-input defaults.
- `ConfirmationPrompt.ask`: Writes the prompt, retries on invalid answers, and returns the configured default when stdin ends.
- `TransferCommand.confirmTransferForNonProject`: Delegates the interactive decision to the shared helper after printing transfer-specific context.
- `SelfUpdateCommand.run`: Uses the shared helper before launching the installer when `--yes` is not set.

## Verification Steps

- `swift test`: Expected all tests, including the new shared prompt tests, to pass.
- `swift run CLI help transfer`: Expected the package to build and the `transfer` command help to render successfully.
- `swift run CLI help self-update`: Expected the package to build and the `self-update` command help to render successfully.

## Future Extension Points

- Add configurable accepted tokens or localized prompt strings in `Sources/SwiftCLIKit/ConfirmationPrompt.swift` if commands need non-English confirmations.
- Introduce styled prompt output through `SwiftCLIKit` if the CLI later standardizes warning or confirmation presentation across commands.
