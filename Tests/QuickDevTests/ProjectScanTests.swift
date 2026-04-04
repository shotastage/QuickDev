import Foundation
import Testing
@testable import QuickDev

@Test func classifierDetectsKnownProjectTypes() throws {
    try withTemporaryDirectory { directoryURL in
        let projectURL = directoryURL.appendingPathComponent("SwiftApp", isDirectory: true)
        try createDirectory(at: projectURL)
        try createFile(at: projectURL.appendingPathComponent("Package.swift"), contents: "// swift-tools-version: 6.0")
        try createDirectory(at: projectURL.appendingPathComponent(".git", isDirectory: true))

        let classifier = ProjectClassifier(fileManager: .default)
        let classification = try classifier.classify(directoryURL: projectURL)

        #expect(classification.isProject)
        #expect(classification.isGitRepository)
        #expect(classification.types == [.swiftPackage, .gitRepository])
    }
}

@Test func scannerFindsProjectsAndSkipsExcludedDirectories() throws {
    try withTemporaryDirectory { directoryURL in
        let swiftURL = directoryURL.appendingPathComponent("SwiftApp", isDirectory: true)
        try createDirectory(at: swiftURL)
        try createFile(at: swiftURL.appendingPathComponent("Package.swift"), contents: "// swift-tools-version: 6.0")
        try createDirectory(at: swiftURL.appendingPathComponent(".git", isDirectory: true))

        let nestedNodeURL = directoryURL
            .appendingPathComponent("Clients", isDirectory: true)
            .appendingPathComponent("WebApp", isDirectory: true)
        try createDirectory(at: nestedNodeURL)
        try createFile(at: nestedNodeURL.appendingPathComponent("package.json"), contents: "{}")

        let gitOnlyURL = directoryURL.appendingPathComponent("GitOnly", isDirectory: true)
        try createDirectory(at: gitOnlyURL)
        try createDirectory(at: gitOnlyURL.appendingPathComponent(".git", isDirectory: true))

        let ignoredURL = directoryURL
            .appendingPathComponent("node_modules", isDirectory: true)
            .appendingPathComponent("Ignored", isDirectory: true)
        try createDirectory(at: ignoredURL)
        try createFile(at: ignoredURL.appendingPathComponent("Package.swift"), contents: "// ignored")

        let tooDeepURL = directoryURL
            .appendingPathComponent("A", isDirectory: true)
            .appendingPathComponent("B", isDirectory: true)
            .appendingPathComponent("TooDeep", isDirectory: true)
        try createDirectory(at: tooDeepURL)
        try createFile(at: tooDeepURL.appendingPathComponent("Package.swift"), contents: "// too deep")

        let scanner = ProjectScanner(
            fileManager: .default,
            classifier: ProjectClassifier(fileManager: .default),
            gitInspector: StubGitInspector(resultsByPath: [
                swiftURL.path: GitInspectionResult(remoteURL: "git@example.com:swift.git", hasUncommittedChanges: true),
                gitOnlyURL.path: GitInspectionResult(remoteURL: nil, hasUncommittedChanges: false),
            ]),
            maximumDepth: 2,
            now: { Date(timeIntervalSince1970: 1_744_000_000) }
        )

        let index = try scanner.scan(rootURL: directoryURL)
        let projectNames = index.projects.map(\.name)

        #expect(projectNames.contains("Clients") == false)
        #expect(projectNames == ["WebApp", "GitOnly", "SwiftApp"])
        #expect(index.projects.map(\.relativePathFromRoot) == ["Clients/WebApp", "GitOnly", "SwiftApp"])
        #expect(index.projects.first(where: { $0.name == "SwiftApp" })?.gitRemoteURL == "git@example.com:swift.git")
        #expect(index.projects.first(where: { $0.name == "SwiftApp" })?.hasUncommittedChanges == true)
        #expect(index.projects.contains(where: { $0.path == ignoredURL.path }) == false)
        #expect(index.projects.contains(where: { $0.path == tooDeepURL.path }) == false)
    }
}

@Test func storePersistsAndLoadsProjectIndex() throws {
    try withTemporaryDirectory { directoryURL in
        let storeURL = directoryURL.appendingPathComponent(".devctl", isDirectory: true)
        let store = ProjectIndexStore(directoryURL: storeURL, fileManager: .default)
        let scanDate = Date(timeIntervalSince1970: 1_744_000_100)
        let index = ProjectIndex(
            version: 1,
            rootPath: "/tmp/Developer",
            scannedAt: scanDate,
            projects: [
                ProjectRecord(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "SwiftApp",
                    path: "/tmp/Developer/SwiftApp",
                    relativePathFromRoot: "SwiftApp",
                    lastModifiedAt: scanDate,
                    detectedTypes: [.swiftPackage, .gitRepository],
                    isGitRepository: true,
                    gitRemoteURL: "git@example.com:swift.git",
                    hasUncommittedChanges: false,
                    primaryLanguage: "Swift",
                    sizeBytes: nil,
                    status: .active,
                    scannedAt: scanDate
                ),
            ]
        )

        let saveResult = try store.save(index)
        let loadedIndex = try #require(try store.loadIndex())

        #expect(FileManager.default.fileExists(atPath: saveResult.indexFileURL.path))
        #expect(FileManager.default.fileExists(atPath: saveResult.scanStateFileURL.path))
        #expect(loadedIndex == index)
    }
}

@Test func storeLoadsOnlyMatchingRootIndexWhenRequested() throws {
    try withTemporaryDirectory { directoryURL in
        let storeURL = directoryURL.appendingPathComponent(".devctl", isDirectory: true)
        let store = ProjectIndexStore(directoryURL: storeURL, fileManager: .default)
        let scanDate = Date(timeIntervalSince1970: 1_744_000_200)
        let index = ProjectIndex(
            version: 1,
            rootPath: "/tmp/Developer",
            scannedAt: scanDate,
            projects: []
        )

        _ = try store.save(index)

        let matchingIndex = try store.loadIndex(matchingRootPath: "/tmp/Developer")
        let mismatchedIndex = try store.loadIndex(matchingRootPath: "/tmp/Work")
        let unfilteredIndex = try store.loadIndex(matchingRootPath: nil)

        #expect(matchingIndex == index)
        #expect(mismatchedIndex == nil)
        #expect(unfilteredIndex == index)
    }
}

@Test func scannerFailsForMissingRoot() {
    let rootURL = URL(fileURLWithPath: "/tmp/quickdev-missing-root-\(UUID().uuidString)", isDirectory: true)
    let scanner = ProjectScanner(fileManager: .default)

    #expect(throws: ProjectScannerError.rootDoesNotExist(rootURL.path)) {
        _ = try scanner.scan(rootURL: rootURL)
    }
}

private struct StubGitInspector: GitInspecting {
    let resultsByPath: [String: GitInspectionResult]

    func inspect(directoryURL: URL) -> GitInspectionResult {
        resultsByPath[directoryURL.path] ?? GitInspectionResult(remoteURL: nil, hasUncommittedChanges: nil)
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevTests-\(UUID().uuidString)", isDirectory: true)
    try createDirectory(at: directoryURL)
    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    try body(directoryURL)
}

private func createDirectory(at url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

private func createFile(at url: URL, contents: String) throws {
    try Data(contents.utf8).write(to: url)
}