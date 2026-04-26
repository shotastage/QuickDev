import Foundation
import Testing
@testable import QuickDev

@Test func archiveWriterCreatesArchiveWithPayloadAndManifest() throws {
    try withTemporaryDirectory { tempURL in
        let projectRootURL = tempURL.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRootURL, withIntermediateDirectories: true)

        let sourceFileURL = projectRootURL.appendingPathComponent("src/main.ts", isDirectory: false)
        try FileManager.default.createDirectory(at: sourceFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("console.log('hello')".utf8).write(to: sourceFileURL)

        let manifest = ArchiveManifest(
            schemaVersion: 1,
            createdAt: "2026-04-20T00:00:00Z",
            quickdevVersion: "0.0.5",
            archiveFormat: "qda",
            compression: "max",
            project: .init(name: "project", originalPath: projectRootURL.path, detectedType: "node", isMonorepo: false),
            git: .init(included: true, headCommit: "abc123", branch: "main", dirty: false),
            stats: .init(originalFileCount: 1, archivedFileCount: 1, originalBytes: 20, archivedBytes: 20, excludedBytesEstimate: 0),
            excluded: [],
            warnings: [],
            restoreHints: .init(packageManager: "pnpm", commands: ["pnpm install --frozen-lockfile", "pnpm build"])
        )

        let outputURL = tempURL.appendingPathComponent("output/sample.qda", isDirectory: false)
        let writeResult = try ArchiveWriter(fileManager: .default).writeArchive(
            projectRootURL: projectRootURL,
            includedEntries: [
                .init(relativePath: "src/main.ts", absolutePath: sourceFileURL.path, type: .file, size: 20),
            ],
            manifest: manifest,
            outputURL: outputURL,
            compression: .max
        )

        #expect(FileManager.default.fileExists(atPath: writeResult.outputURL.path))
        #expect(writeResult.archivedBytes > 0)

        try ArchiveWriter(fileManager: .default).verifyArchive(at: writeResult.outputURL)

        let listed = try listArchiveEntries(at: writeResult.outputURL)
        #expect(listed.contains("payload/src/main.ts"))
        #expect(listed.contains("meta/archive.json"))

        let extractedManifest = try extractManifest(from: writeResult.outputURL, baseDirectory: tempURL)
        #expect(extractedManifest.schemaVersion == 1)
        #expect(extractedManifest.project.name == "project")
    }
}

private func listArchiveEntries(at archiveURL: URL) throws -> [String] {
    let result = try runProcess(executable: "tar", arguments: ["-tzf", archiveURL.path])
    #expect(result.status == 0)

    return result.stdout
        .split(separator: "\n")
        .map(String.init)
}

private func extractManifest(from archiveURL: URL, baseDirectory: URL) throws -> ArchiveManifest {
    let extractDirectoryURL = baseDirectory.appendingPathComponent("extract", isDirectory: true)
    try FileManager.default.createDirectory(at: extractDirectoryURL, withIntermediateDirectories: true)

    let extraction = try runProcess(
        executable: "tar",
        arguments: ["-xzf", archiveURL.path, "-C", extractDirectoryURL.path, "meta/archive.json"]
    )
    #expect(extraction.status == 0)

    let manifestURL = extractDirectoryURL.appendingPathComponent("meta/archive.json", isDirectory: false)
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(ArchiveManifest.self, from: data)
}

private func runProcess(executable: String, arguments: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [executable] + arguments
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
    return (process.terminationStatus, stdout, stderr)
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevArchiveWriterTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempURL)
    }

    try body(tempURL)
}
