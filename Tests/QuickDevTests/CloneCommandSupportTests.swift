import Foundation
import Testing
@testable import CLI

@Test func extractRepositoryNameSupportsHTTPSAndSSH() throws {
    #expect(try CloneCommandSupport.extractRepositoryName(from: "https://github.com/user/example.git") == "example")
    #expect(try CloneCommandSupport.extractRepositoryName(from: "https://github.com/user/example") == "example")
    #expect(try CloneCommandSupport.extractRepositoryName(from: "git@github.com:user/example.git") == "example")
}

@Test func extractRepositoryNameThrowsForInvalidRepositoryURL() {
    #expect(throws: CloneCommandError.invalidRepositoryURL) {
        _ = try CloneCommandSupport.extractRepositoryName(from: "invalid-url")
    }
}

@Test func buildCloneTargetPathCreatesDeveloperRootUnderHomeDirectory() throws {
    try withTemporaryDirectory { homeDirectoryURL in
        let targetURL = try CloneCommandSupport.buildCloneTargetPath(
            for: "example",
            fileManager: .default,
            homeDirectoryURL: homeDirectoryURL
        )

        let expectedURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("example", isDirectory: true)
            .standardizedFileURL
        let developerRootURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        #expect(targetURL == expectedURL)
        #expect(FileManager.default.fileExists(atPath: developerRootURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }
}

@Test func buildCloneTargetPathFailsWhenTargetDirectoryAlreadyExists() throws {
    try withTemporaryDirectory { homeDirectoryURL in
        let existingTargetURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("example", isDirectory: true)
            .standardizedFileURL

        try FileManager.default.createDirectory(at: existingTargetURL, withIntermediateDirectories: true)

        #expect(throws: CloneCommandError.targetDirectoryAlreadyExists(existingTargetURL)) {
            _ = try CloneCommandSupport.buildCloneTargetPath(
                for: "example",
                fileManager: .default,
                homeDirectoryURL: homeDirectoryURL
            )
        }
    }
}

@Test func displayPathUsesTildeForHomeRelativePath() {
    let homeDirectoryURL = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    let targetURL = homeDirectoryURL
        .appendingPathComponent("Developer", isDirectory: true)
        .appendingPathComponent("example", isDirectory: true)

    #expect(
        CloneCommandSupport.displayPath(targetURL, homeDirectoryURL: homeDirectoryURL)
            == "~/Developer/example"
    )
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevCloneCommandTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }

    try body(temporaryDirectoryURL)
}
