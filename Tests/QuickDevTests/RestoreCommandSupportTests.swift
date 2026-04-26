import Foundation
import Testing
@testable import CLI
@testable import QuickDev

@Test func resolveArchiveURLResolvesRelativePathFromCurrentDirectory() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let currentDirectoryPath = FileManager.default.currentDirectoryPath
        defer {
            _ = FileManager.default.changeCurrentDirectoryPath(currentDirectoryPath)
        }

        let changed = FileManager.default.changeCurrentDirectoryPath(temporaryDirectoryURL.path)
        #expect(changed)

        let archiveURL = temporaryDirectoryURL
            .appendingPathComponent("project.qda", isDirectory: false)
            .standardizedFileURL
        try Data("archive".utf8).write(to: archiveURL)

        let resolvedURL = try RestoreCommandSupport.resolveArchiveURL(
            from: "project.qda",
            fileManager: .default
        )

        #expect(resolvedURL == archiveURL)
    }
}

@Test func buildRestoreDestinationPathDefaultsToDeveloperDirectory() throws {
    let manifest = ArchiveManifest(
        schemaVersion: 1,
        createdAt: "2026-04-26T00:00:00Z",
        quickdevVersion: "0.0.5",
        archiveFormat: "qda",
        compression: "default",
        project: .init(name: "DemoApp", originalPath: "/tmp/DemoApp", detectedType: "node", isMonorepo: false),
        git: .init(included: false, headCommit: nil, branch: nil, dirty: nil),
        stats: .init(originalFileCount: 1, archivedFileCount: 1, originalBytes: 1, archivedBytes: 1, excludedBytesEstimate: 0),
        excluded: [],
        warnings: [],
        restoreHints: .init(packageManager: "npm", commands: ["npm ci"])
    )
    let homeDirectoryURL = URL(fileURLWithPath: "/tmp/home", isDirectory: true)

    let destinationURL = try RestoreCommandSupport.buildRestoreDestinationPath(
        manifest: manifest,
        destinationPath: nil,
        fileManager: .default,
        homeDirectoryURL: homeDirectoryURL
    )

    #expect(destinationURL.path == "/tmp/home/Developer/DemoApp")
}

@Test func buildRestoreDestinationPathRejectsEmptyCustomPath() {
    let manifest = ArchiveManifest(
        schemaVersion: 1,
        createdAt: "2026-04-26T00:00:00Z",
        quickdevVersion: "0.0.5",
        archiveFormat: "qda",
        compression: "default",
        project: .init(name: "DemoApp", originalPath: "/tmp/DemoApp", detectedType: "node", isMonorepo: false),
        git: .init(included: false, headCommit: nil, branch: nil, dirty: nil),
        stats: .init(originalFileCount: 1, archivedFileCount: 1, originalBytes: 1, archivedBytes: 1, excludedBytesEstimate: 0),
        excluded: [],
        warnings: [],
        restoreHints: .init(packageManager: "npm", commands: ["npm ci"])
    )

    #expect(throws: RestoreCommandError.emptyDestinationPath) {
        _ = try RestoreCommandSupport.buildRestoreDestinationPath(
            manifest: manifest,
            destinationPath: "   ",
            fileManager: .default,
            homeDirectoryURL: URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        )
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevRestoreCommandSupportTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }

    try body(temporaryDirectoryURL)
}
