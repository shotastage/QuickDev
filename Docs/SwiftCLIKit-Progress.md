# SwiftCLIKit Progress Bar Guide

This document describes how to use the terminal progress bar APIs provided by `SwiftCLIKit`.

## Overview

`SwiftCLIKit` currently exposes four progress-related types:

- `ProgressBarStyle`: visual settings for the bar.
- `ProgressBarState`: current progress snapshot.
- `ProgressBarRenderer`: pure string renderer for tests or custom output flows.
- `TerminalProgressBar`: terminal writer that updates a single line in place.

The implementation is intended for CLI tools that need lightweight progress output for downloads, uploads, file processing, or other sequential work.

## Import

If your target depends on the `SwiftCLIKit` product, import it as usual:

```swift
import SwiftCLIKit
```

If you are consuming this package from another Swift package, add the product to your target dependencies:

```swift
.target(
    name: "MyTool",
    dependencies: [
        .product(name: "SwiftCLIKit", package: "QuickDev")
    ]
)
```

## Quick Start

Use `TerminalProgressBar` when you want to render directly to the terminal.

```swift
import Foundation
import SwiftCLIKit

let progressBar = TerminalProgressBar()
let totalBytes: Int64 = 100

for downloadedBytes in stride(from: Int64(0), through: totalBytes, by: 10) {
    progressBar.update(
        .init(
            completedUnitCount: downloadedBytes,
            totalUnitCount: totalBytes,
            message: "Downloading"
        )
    )

    Thread.sleep(forTimeInterval: 0.05)
}

progressBar.finish(
    with: .init(
        completedUnitCount: totalBytes,
        totalUnitCount: totalBytes,
        message: "Download complete"
    )
)
```

Typical output looks like this while the command is running:

```text
Downloading [############--------]  50% 50/100
```

## Core Types

### `ProgressBarStyle`

Use this type to customize how the bar is rendered.

```swift
let style = ProgressBarStyle(
    barWidth: 30,
    completeCharacter: "=",
    incompleteCharacter: ".",
    leftDelimiter: "|",
    rightDelimiter: "|",
    percentageWidth: 3,
    includesCounts: true
)
```

Behavior notes:

- `barWidth` is clamped to at least `1`.
- `percentageWidth` is clamped to at least `0`.
- If `percentageWidth` is `0`, the percentage column is omitted.
- If `includesCounts` is `false`, the `completed/total` suffix is omitted.

### `ProgressBarState`

This is the input snapshot for rendering.

```swift
let state = ProgressBarState(
    completedUnitCount: 42,
    totalUnitCount: 100,
    message: "Uploading"
)
```

Behavior notes:

- `message` is trimmed before rendering. Empty or whitespace-only messages are omitted.
- `fractionCompleted` returns `0` when `totalUnitCount <= 0`.
- The filled portion of the bar is clamped between `0` and `totalUnitCount`.
- The displayed `completed/total` counts are not normalized to match the visual clamp. For example, `10/8` still displays as `10/8` while the bar renders as `100%`.

### `ProgressBarRenderer`

Use the renderer when you need the progress line as a string instead of writing directly to the terminal.

```swift
let renderer = ProgressBarRenderer(style: .init(barWidth: 10))

let line = renderer.render(
    .init(completedUnitCount: 5, totalUnitCount: 10, message: "Download")
)

print(line)
// Download [#####-----]  50% 5/10
```

This is the best entry point for unit tests or for integrating with custom logging/output systems.

### `TerminalProgressBar`

Use this type when you want in-place updates on a terminal line.

```swift
let progressBar = TerminalProgressBar(style: .init(barWidth: 20))

progressBar.update(.init(completedUnitCount: 25, totalUnitCount: 100, message: "Indexing"))
progressBar.update(.init(completedUnitCount: 75, totalUnitCount: 100, message: "Indexing"))
progressBar.finish(with: .init(completedUnitCount: 100, totalUnitCount: 100, message: "Done"))
```

Behavior notes:

- Output is written to standard error by default.
- The class uses a lock internally so repeated updates are serialized.
- `update` rewrites the current line using `\r`.
- `finish(with:)` writes the final line and appends a newline.
- `finish()` without a state only appends a newline.
- Additional `update` or `finish` calls after finishing are ignored.
- If a later line is shorter than a previous line, trailing characters are cleared with spaces.

## Custom Output

You can inject a custom writer closure instead of writing to standard error.

```swift
var capturedOutput = ""

let progressBar = TerminalProgressBar(
    writer: { capturedOutput += $0 }
)

progressBar.update(.init(completedUnitCount: 1, totalUnitCount: 4, message: "Step"))
progressBar.finish(with: .init(completedUnitCount: 4, totalUnitCount: 4, message: "Done"))
```

This is useful for tests, alternative console abstractions, or piping output somewhere other than the active terminal.

## Recommended Usage Pattern

For long-running operations:

1. Create one `TerminalProgressBar` instance per active task.
2. Call `update` whenever the completed amount changes.
3. Call `finish(with:)` exactly once when the task completes.
4. Keep progress updates deterministic and avoid mixing unrelated `stdout` logs onto the same line.

If your command prints normal status logs, prefer sending the progress bar to standard error and regular results to standard output. That keeps machine-readable output cleaner.

## Limitations

- The current implementation assumes a terminal that understands carriage-return based line rewriting.
- It does not currently provide spinners, ETA, transfer speeds, or byte-size formatting.
- It does not auto-detect terminal width.
- Multi-line progress layouts are not supported.

If those features are needed later, they should be added on top of `ProgressBarState` and `ProgressBarRenderer` rather than bypassing them.
