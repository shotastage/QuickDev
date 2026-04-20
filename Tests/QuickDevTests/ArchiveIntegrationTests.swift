import Foundation
import Testing
@testable import QuickDev

@Test func archiveIntegrationNextJSProjectExcludesBuildArtifactsAndKeepsDotenv() throws {
    try withTemporaryDirectory { tempURL in
        let projectRootURL = tempURL.appendingPathComponent("next-app", isDirectory: true)
        try createDirectory(at: projectRootURL)
        try createFile(at: projectRootURL.appendingPathComponent("package.json"), contents: "{\"name\":\"next-app\"}")
        try createFile(at: projectRootURL.appendingPathComponent("pnpm-lock.yaml"), contents: "lockfileVersion: '9.0'")
        try createFile(at: projectRootURL.appendingPathComponent(".env"), contents: "SECRET=value")
        try createFile(at: projectRootURL.appendingPathComponent("src/index.ts"), contents: "export {};\n")
        try createFile(at: projectRootURL.appendingPathComponent("node_modules/react/index.js"), contents: "module.exports = {}")
        try createFile(at: projectRootURL.appendingPathComponent(".next/cache/build.json"), contents: "{}")

        let detector = ArchiveProjectDetector(fileManager: .default)
        let project = try detector.detectProject(targetPath: projectRootURL.path)
        let policy = ArchivePolicyBuilder().makePolicy(project: project, extraExcludePatterns: [], keepGit: true)
        let scanned = try ArchiveFileScanner(fileManager: .default).scan(projectRootURL: project.rootURL)
        let plan = ArchivePlanner().plan(scannedEntries: scanned, policy: policy)

        #expect(plan.excluded.contains(where: { $0.path == "node_modules" }))
        #expect(plan.excluded.contains(where: { $0.path == ".next" }))
        #expect(plan.warnings.contains(where: { $0.path == ".env" && $0.reason == "environment_file_detected" }))
        #expect(plan.included.contains(where: { $0.relativePath == ".env" }))

        let outputResolver = ArchiveOutputPathResolver(
            fileManager: .default,
            now: { Date(timeIntervalSince1970: 1_776_696_000) },
            homeDirectoryProvider: { tempURL },
            currentDirectoryProvider: { tempURL }
        )
        let outputURL = try outputResolver.resolveOutputPath(projectName: project.name, outputPath: nil)

        #expect(outputURL.path.contains("/.quickdev/archive/"))

        let gitInfo = ArchiveGitMetadataCollector(fileManager: .default).collect(projectRootURL: project.rootURL, includeGitDirectory: true)
        let manifest = ArchiveManifestBuilder().buildManifest(
            project: project,
            plan: plan,
            git: gitInfo.gitInfo,
            compression: .max,
            quickdevVersion: "0.0.5",
            archivedBytes: 0,
            additionalWarnings: gitInfo.warnings
        )

        let writeResult = try ArchiveWriter(fileManager: .default).writeArchive(
            projectRootURL: project.rootURL,
            includedEntries: plan.included,
            manifest: manifest,
            outputURL: outputURL,
            compression: .max
        )
        try ArchiveWriter(fileManager: .default).verifyArchive(at: writeResult.outputURL)

        let archivedManifest = try extractManifest(from: writeResult.outputURL, baseDirectory: tempURL)
        #expect(archivedManifest.excluded.contains(where: { $0.path == "node_modules" }))
        #expect(archivedManifest.excluded.contains(where: { $0.path == ".next" }))
        #expect(archivedManifest.warnings.contains(where: { $0.path == ".env" && $0.reason == "environment_file_detected" }))
    }
}

@Test func archiveIntegrationUnknownProjectDoesNotAggressivelyExcludeBuildDirectory() throws {
    try withTemporaryDirectory { tempURL in
        let projectRootURL = tempURL.appendingPathComponent("unknown", isDirectory: true)
        try createDirectory(at: projectRootURL)
        try createFile(at: projectRootURL.appendingPathComponent("build/output.bin"), contents: "123")
        try createFile(at: projectRootURL.appendingPathComponent("tmp/cache.tmp"), contents: "x")

        let project = try ArchiveProjectDetector(fileManager: .default).detectProject(targetPath: projectRootURL.path)
        #expect(project.type == .unknown)

        let policy = ArchivePolicyBuilder().makePolicy(project: project, extraExcludePatterns: [], keepGit: true)
        let scanned = try ArchiveFileScanner(fileManager: .default).scan(projectRootURL: project.rootURL)
        let plan = ArchivePlanner().plan(scannedEntries: scanned, policy: policy)

        #expect(plan.included.contains(where: { $0.relativePath == "build/output.bin" }))
        #expect(plan.excluded.contains(where: { $0.path == "tmp" }))
    }
}

@Test func archiveIntegrationDatabaseFileIsKeptWithWarning() throws {
    try withTemporaryDirectory { tempURL in
        let projectRootURL = tempURL.appendingPathComponent("db-project", isDirectory: true)
        try createDirectory(at: projectRootURL)
        try createFile(at: projectRootURL.appendingPathComponent("package.json"), contents: "{}")
        try createFile(at: projectRootURL.appendingPathComponent("data/app.db"), contents: "sqlite")

        let project = try ArchiveProjectDetector(fileManager: .default).detectProject(targetPath: projectRootURL.path)
        let policy = ArchivePolicyBuilder().makePolicy(project: project, extraExcludePatterns: [], keepGit: true)
        let scanned = try ArchiveFileScanner(fileManager: .default).scan(projectRootURL: project.rootURL)
        let plan = ArchivePlanner().plan(scannedEntries: scanned, policy: policy)

        #expect(plan.included.contains(where: { $0.relativePath == "data/app.db" }))
        #expect(plan.warnings.contains(where: { $0.path == "data/app.db" && $0.reason == "local_database_detected" }))
    }
}

@Test func archiveIntegrationOutputPathConflictUsesIncrementedSuffix() throws {
    try withTemporaryDirectory { tempURL in
        let resolver = ArchiveOutputPathResolver(
            fileManager: .default,
            now: { Date(timeIntervalSince1970: 1_776_696_000) },
            homeDirectoryProvider: { tempURL },
            currentDirectoryProvider: { tempURL }
        )

        let first = try resolver.resolveOutputPath(projectName: "conflict", outputPath: nil)
        try Data("first".utf8).write(to: first)

        let second = try resolver.resolveOutputPath(projectName: "conflict", outputPath: nil)
        #expect(second.lastPathComponent.hasSuffix("-2.qda"))
    }
}

private func extractManifest(from archiveURL: URL, baseDirectory: URL) throws -> ArchiveManifest {
    let extractDirectoryURL = baseDirectory.appendingPathComponent("extract-manifest", isDirectory: true)
    try FileManager.default.createDirectory(at: extractDirectoryURL, withIntermediateDirectories: true)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["tar", "-xzf", archiveURL.path, "-C", extractDirectoryURL.path, "meta/archive.json"]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    let manifestURL = extractDirectoryURL.appendingPathComponent("meta/archive.json", isDirectory: false)
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(ArchiveManifest.self, from: data)
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevArchiveIntegrationTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempURL)
    }

    try body(tempURL)
}

private func createDirectory(at url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

private func createFile(at url: URL, contents: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: url)
}
