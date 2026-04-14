import Foundation
import Testing
@testable import CLI

@Test func resolveSourceDirectoryURLResolvesRelativePathFromCurrentDirectory() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let currentDirectoryPath = FileManager.default.currentDirectoryPath
        defer {
            _ = FileManager.default.changeCurrentDirectoryPath(currentDirectoryPath)
        }

        let changed = FileManager.default.changeCurrentDirectoryPath(temporaryDirectoryURL.path)
        #expect(changed)

        let sourceDirectoryURL = temporaryDirectoryURL
            .appendingPathComponent("SampleProject", isDirectory: true)
            .standardizedFileURL
        try createDirectory(at: sourceDirectoryURL)

        let resolvedURL = try RegisterCommandSupport.resolveSourceDirectoryURL(
            from: "SampleProject",
            fileManager: .default
        )

        #expect(resolvedURL == sourceDirectoryURL)
    }
}

@Test func resolveSourceDirectoryURLRejectsFilePath() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let fileURL = temporaryDirectoryURL
            .appendingPathComponent("README.md", isDirectory: false)
            .standardizedFileURL
        let expectedPathURL = URL(fileURLWithPath: fileURL.path, isDirectory: true).standardizedFileURL
        try Data("hello".utf8).write(to: fileURL)

        #expect(throws: RegisterCommandError.sourcePathIsNotDirectory(expectedPathURL)) {
            _ = try RegisterCommandSupport.resolveSourceDirectoryURL(
                from: fileURL.path,
                fileManager: .default
            )
        }
    }
}

@Test func buildRegisterDestinationPathCreatesDeveloperRootAndResolvesTarget() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let homeDirectoryURL = temporaryDirectoryURL
            .appendingPathComponent("home", isDirectory: true)
            .standardizedFileURL
        let sourceDirectoryURL = temporaryDirectoryURL
            .appendingPathComponent("source", isDirectory: true)
            .appendingPathComponent("DemoApp", isDirectory: true)
            .standardizedFileURL

        try createDirectory(at: homeDirectoryURL)
        try createDirectory(at: sourceDirectoryURL)

        let destinationURL = try RegisterCommandSupport.buildRegisterDestinationPath(
            for: sourceDirectoryURL,
            fileManager: .default,
            homeDirectoryURL: homeDirectoryURL
        )

        let expectedDestinationURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("DemoApp", isDirectory: true)
            .standardizedFileURL
        let expectedDeveloperRootURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        #expect(destinationURL == expectedDestinationURL)
        #expect(FileManager.default.fileExists(atPath: expectedDeveloperRootURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }
}

@Test func buildRegisterDestinationPathRejectsDirectoriesAlreadyInDeveloperRoot() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let homeDirectoryURL = temporaryDirectoryURL
            .appendingPathComponent("home", isDirectory: true)
            .standardizedFileURL
        let sourceDirectoryURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("DemoApp", isDirectory: true)
            .standardizedFileURL

        try createDirectory(at: sourceDirectoryURL)

        #expect(throws: RegisterCommandError.sourceAlreadyInDeveloperRoot(sourceDirectoryURL)) {
            _ = try RegisterCommandSupport.buildRegisterDestinationPath(
                for: sourceDirectoryURL,
                fileManager: .default,
                homeDirectoryURL: homeDirectoryURL
            )
        }
    }
}

@Test func buildRegisterDestinationPathRejectsExistingTargetDirectory() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let homeDirectoryURL = temporaryDirectoryURL
            .appendingPathComponent("home", isDirectory: true)
            .standardizedFileURL
        let sourceDirectoryURL = temporaryDirectoryURL
            .appendingPathComponent("workspace", isDirectory: true)
            .appendingPathComponent("DemoApp", isDirectory: true)
            .standardizedFileURL
        let targetDirectoryURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("DemoApp", isDirectory: true)
            .standardizedFileURL

        try createDirectory(at: sourceDirectoryURL)
        try createDirectory(at: targetDirectoryURL)

        #expect(throws: RegisterCommandError.targetDirectoryAlreadyExists(targetDirectoryURL)) {
            _ = try RegisterCommandSupport.buildRegisterDestinationPath(
                for: sourceDirectoryURL,
                fileManager: .default,
                homeDirectoryURL: homeDirectoryURL
            )
        }
    }
}

@Test func buildRegisterDestinationPathRejectsMovingDirectoryIntoDescendant() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let sourceDirectoryURL = temporaryDirectoryURL.standardizedFileURL

        #expect(throws: RegisterCommandError.sourceContainsDestination(sourceDirectoryURL)) {
            _ = try RegisterCommandSupport.buildRegisterDestinationPath(
                for: sourceDirectoryURL,
                fileManager: .default,
                homeDirectoryURL: sourceDirectoryURL
            )
        }
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevRegisterCommandTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }

    try body(temporaryDirectoryURL)
}

private func createDirectory(at url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}