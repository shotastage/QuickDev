import Foundation
import Testing
@testable import QuickDev

@Test func archiveOutputPathResolverReturnsExplicitOutputPathWhenProvided() throws {
    try withTemporaryDirectory { tempURL in
        let resolver = ArchiveOutputPathResolver(
            fileManager: .default,
            now: { Date(timeIntervalSince1970: 1_776_696_000) },
            homeDirectoryProvider: { tempURL },
            currentDirectoryProvider: { tempURL }
        )

        let resolved = try resolver.resolveOutputPath(projectName: "demo", outputPath: "./archives/demo.qda")
        let expected = tempURL.appendingPathComponent("archives", isDirectory: true).appendingPathComponent("demo.qda")
        #expect(resolved == expected.standardizedFileURL)
    }
}

@Test func archiveOutputPathResolverUsesQuickDevArchiveDirectoryByDefault() throws {
    try withTemporaryDirectory { tempURL in
        let resolver = ArchiveOutputPathResolver(
            fileManager: .default,
            now: { Date(timeIntervalSince1970: 1_776_696_000) },
            homeDirectoryProvider: { tempURL },
            currentDirectoryProvider: { tempURL }
        )

        let resolved = try resolver.resolveOutputPath(projectName: "my app", outputPath: nil)
        let expectedDirectory = tempURL
            .appendingPathComponent(".quickdev", isDirectory: true)
            .appendingPathComponent("archive", isDirectory: true)
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: expectedDirectory.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(resolved.path.hasPrefix(expectedDirectory.path + "/"))
        #expect(resolved.pathExtension == "qda")
    }
}

@Test func archiveOutputPathResolverAddsSuffixWhenNameCollides() throws {
    try withTemporaryDirectory { tempURL in
        let fixedDate = Date(timeIntervalSince1970: 1_776_696_000)
        let resolver = ArchiveOutputPathResolver(
            fileManager: .default,
            now: { fixedDate },
            homeDirectoryProvider: { tempURL },
            currentDirectoryProvider: { tempURL }
        )

        let firstPath = try resolver.resolveOutputPath(projectName: "demo", outputPath: nil)
        try Data("x".utf8).write(to: firstPath)

        let secondPath = try resolver.resolveOutputPath(projectName: "demo", outputPath: nil)
        #expect(secondPath.lastPathComponent.contains("-2.qda"))
    }
}

@Test func archiveOutputPathResolverSanitizesProjectNames() {
    let resolver = ArchiveOutputPathResolver(fileManager: .default)
    #expect(resolver.sanitizeFileName("my:project / name") == "my-project-name")
    #expect(resolver.sanitizeFileName("   ") == "project")
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevArchiveOutputPathResolverTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempURL)
    }

    try body(tempURL)
}
