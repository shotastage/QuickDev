import Foundation
import Testing
@testable import CLI
@testable import QuickDev

@Test func refreshIndexScansRootAndPersistsIndex() throws {
    try withTemporaryDirectory { temporaryDirectoryURL in
        let rootURL = temporaryDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .standardizedFileURL
        let projectURL = rootURL
            .appendingPathComponent("ExampleApp", isDirectory: true)
            .standardizedFileURL
        let storeURL = temporaryDirectoryURL
            .appendingPathComponent(".devctl", isDirectory: true)
            .standardizedFileURL

        try createDirectory(at: projectURL)
        try createDirectory(at: projectURL.appendingPathComponent(".git", isDirectory: true))
        try createFile(at: projectURL.appendingPathComponent("Package.swift"), contents: "// swift-tools-version: 6.3")

        let support = ProjectIndexCommandSupport(fileManager: .default)
        let scanner = ProjectScanner(fileManager: .default)
        let store = ProjectIndexStore(directoryURL: storeURL, fileManager: .default)

        let refreshResult = try support.refreshIndex(scanner: scanner, store: store, rootURL: rootURL)

        #expect(refreshResult.rootURL == rootURL)
        #expect(refreshResult.index.rootPath == rootURL.path)
        #expect(refreshResult.index.projects.map(\.name) == ["ExampleApp"])
        #expect(FileManager.default.fileExists(atPath: refreshResult.saveResult.indexFileURL.path))
        #expect(FileManager.default.fileExists(atPath: refreshResult.saveResult.scanStateFileURL.path))
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevProjectIndexSupportTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }

    try body(temporaryDirectoryURL)
}

private func createDirectory(at url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

private func createFile(at url: URL, contents: String) throws {
    try Data(contents.utf8).write(to: url)
}
