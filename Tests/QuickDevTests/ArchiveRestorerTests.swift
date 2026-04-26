import Foundation
import Testing
@testable import QuickDev

@Test func archiveRestorerRestoresPayloadIntoDestinationDirectory() throws {
    try withTemporaryDirectory { tempURL in
        let projectRootURL = tempURL.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRootURL, withIntermediateDirectories: true)

        let packageURL = projectRootURL.appendingPathComponent("package.json", isDirectory: false)
        let sourceURL = projectRootURL.appendingPathComponent("src/index.ts", isDirectory: false)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"name\":\"project\"}".utf8).write(to: packageURL)
        try Data("export const answer = 42;\n".utf8).write(to: sourceURL)

        let archiveURL = tempURL.appendingPathComponent("archives/project.qda", isDirectory: false)
        try createArchive(
            projectRootURL: projectRootURL,
            includedEntries: [
                .init(relativePath: "package.json", absolutePath: packageURL.path, type: .file, size: 18),
                .init(relativePath: "src/index.ts", absolutePath: sourceURL.path, type: .file, size: 26),
            ],
            archiveURL: archiveURL
        )

        let destinationURL = tempURL.appendingPathComponent("restore/project", isDirectory: true)
        let result = try ArchiveRestorer(fileManager: .default).restoreArchive(at: archiveURL, to: destinationURL)

        #expect(result.destinationURL == destinationURL.standardizedFileURL)
        #expect(result.manifest.project.name == "project")
        #expect(FileManager.default.fileExists(atPath: destinationURL.appendingPathComponent("package.json").path))
        let restoredSourceURL = destinationURL.appendingPathComponent("src/index.ts", isDirectory: false)
        let restoredContents = try String(contentsOf: restoredSourceURL, encoding: .utf8)
        #expect(restoredContents == "export const answer = 42;\n")
    }
}

@Test func archiveRestorerRejectsExistingDestinationDirectory() throws {
    try withTemporaryDirectory { tempURL in
        let projectRootURL = tempURL.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRootURL, withIntermediateDirectories: true)

        let sourceURL = projectRootURL.appendingPathComponent("README.md", isDirectory: false)
        try Data("hello\n".utf8).write(to: sourceURL)

        let archiveURL = tempURL.appendingPathComponent("archives/project.qda", isDirectory: false)
        try createArchive(
            projectRootURL: projectRootURL,
            includedEntries: [
                .init(relativePath: "README.md", absolutePath: sourceURL.path, type: .file, size: 6),
            ],
            archiveURL: archiveURL
        )

        let destinationURL = tempURL.appendingPathComponent("restore/project", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        #expect(throws: ArchiveRestorerError.destinationAlreadyExists(destinationURL.standardizedFileURL.path)) {
            _ = try ArchiveRestorer(fileManager: .default).restoreArchive(at: archiveURL, to: destinationURL)
        }
    }
}

@Test func archiveRestorerRejectsUnexpectedArchiveEntries() throws {
    try withTemporaryDirectory { tempURL in
        let archiveURL = tempURL.appendingPathComponent("archives/unsafe.qda", isDirectory: false)
        try createArchiveWithUnexpectedTopLevelFile(at: archiveURL, baseDirectory: tempURL)

        #expect(throws: ArchiveRestorerError.unsafeArchiveEntry("evil.txt")) {
            _ = try ArchiveRestorer(fileManager: .default).inspectArchive(at: archiveURL)
        }
    }
}

private func createArchive(
    projectRootURL: URL,
    includedEntries: [ArchiveScannedEntry],
    archiveURL: URL
) throws {
    let manifest = ArchiveManifest(
        schemaVersion: 1,
        createdAt: "2026-04-26T00:00:00Z",
        quickdevVersion: "0.0.5",
        archiveFormat: "qda",
        compression: "default",
        project: .init(
            name: projectRootURL.lastPathComponent,
            originalPath: projectRootURL.path,
            detectedType: "node",
            isMonorepo: false
        ),
        git: .init(included: true, headCommit: "abc123", branch: "main", dirty: false),
        stats: .init(
            originalFileCount: includedEntries.count,
            archivedFileCount: includedEntries.count,
            originalBytes: includedEntries.reduce(0) { $0 + $1.size },
            archivedBytes: includedEntries.reduce(0) { $0 + $1.size },
            excludedBytesEstimate: 0
        ),
        excluded: [],
        warnings: [],
        restoreHints: .init(packageManager: "npm", commands: ["npm ci", "npm run build"])
    )

    _ = try ArchiveWriter(fileManager: .default).writeArchive(
        projectRootURL: projectRootURL,
        includedEntries: includedEntries,
        manifest: manifest,
        outputURL: archiveURL,
        compression: .default
    )
}

private func createArchiveWithUnexpectedTopLevelFile(at archiveURL: URL, baseDirectory: URL) throws {
    let stagingURL = baseDirectory.appendingPathComponent("unsafe-staging", isDirectory: true)
    let payloadURL = stagingURL.appendingPathComponent("payload", isDirectory: true)
    let metaURL = stagingURL.appendingPathComponent("meta", isDirectory: true)
    try FileManager.default.createDirectory(at: payloadURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: metaURL, withIntermediateDirectories: true)

    try Data("hello\n".utf8).write(to: payloadURL.appendingPathComponent("README.md", isDirectory: false))

    let manifest = ArchiveManifest(
        schemaVersion: 1,
        createdAt: "2026-04-26T00:00:00Z",
        quickdevVersion: "0.0.5",
        archiveFormat: "qda",
        compression: "default",
        project: .init(name: "unsafe", originalPath: "/tmp/unsafe", detectedType: "node", isMonorepo: false),
        git: .init(included: false, headCommit: nil, branch: nil, dirty: nil),
        stats: .init(originalFileCount: 1, archivedFileCount: 1, originalBytes: 6, archivedBytes: 6, excludedBytesEstimate: 0),
        excluded: [],
        warnings: [],
        restoreHints: .init(packageManager: "npm", commands: ["npm ci"])
    )

    let manifestData = try JSONEncoder().encode(manifest)
    try manifestData.write(to: metaURL.appendingPathComponent("archive.json", isDirectory: false))
    try Data("boom\n".utf8).write(to: stagingURL.appendingPathComponent("evil.txt", isDirectory: false))

    try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let tarURL = baseDirectory.appendingPathComponent("unsafe.tar", isDirectory: false)

    let tarProcess = Process()
    tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    tarProcess.arguments = ["tar", "-cf", tarURL.path, "-C", stagingURL.path, "payload", "meta", "evil.txt"]
    try tarProcess.run()
    tarProcess.waitUntilExit()
    #expect(tarProcess.terminationStatus == 0)

    let gzipProcess = Process()
    gzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    gzipProcess.arguments = ["gzip", "-n", "-6", tarURL.path]
    try gzipProcess.run()
    gzipProcess.waitUntilExit()
    #expect(gzipProcess.terminationStatus == 0)

    try FileManager.default.moveItem(at: URL(fileURLWithPath: tarURL.path + ".gz"), to: archiveURL)
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevArchiveRestorerTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }

    try body(temporaryDirectoryURL)
}
