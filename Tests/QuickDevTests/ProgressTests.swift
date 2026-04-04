import Testing
@testable import SwiftCLIKit

private func escapedControlCharacters(in text: String) -> String {
    text.unicodeScalars.map {
        switch $0.value {
        case 13:
            return "\\r"
        case 10:
            return "\\n"
        default:
            return String($0)
        }
    }.joined()
}

@Test func rendersProgressBarLine() {
    let renderer = ProgressBarRenderer(style: .init(barWidth: 10))

    let line = renderer.render(
        .init(completedUnitCount: 5, totalUnitCount: 10, message: "Download")
    )

    #expect(line == "Download [#####-----]  50% 5/10")
}

@Test func clampsFractionWithoutChangingDisplayedCounts() {
    let renderer = ProgressBarRenderer(style: .init(barWidth: 4))

    let line = renderer.render(
        .init(completedUnitCount: 10, totalUnitCount: 8, message: "Upload")
    )

    #expect(line == "Upload [####] 100% 10/8")
}

@Test func terminalProgressBarClearsTrailingCharactersOnShorterUpdates() {
    var output = ""
    let progressBar = TerminalProgressBar(
        style: .init(barWidth: 4, includesCounts: false),
        writer: { output += $0 }
    )

    progressBar.update(.init(completedUnitCount: 1, totalUnitCount: 4, message: "Longer"))
    progressBar.finish(with: .init(completedUnitCount: 4, totalUnitCount: 4, message: "Done"))

    #expect(escapedControlCharacters(in: output) == "\\rLonger [#---]  25%\\rDone [####] 100%  \\n")
}