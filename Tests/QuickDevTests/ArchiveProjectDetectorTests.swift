import Foundation
import Testing
@testable import QuickDev

@Test func archiveProjectDetectorDetectsNodeProjectFromPackageJSON() throws {
    try withTemporaryDirectory { rootURL in
        let projectURL = rootURL.appendingPathComponent("web-app", isDirectory: true)
        try createDirectory(at: projectURL)
        try createFile(at: projectURL.appendingPathComponent("package.json"), contents: "{}")

        let detector = ArchiveProjectDetector(fileManager: .default)
        let project = try detector.detectProject(targetPath: projectURL.path)

        #expect(project.type == .node)
        #expect(project.name == "web-app")
        #expect(project.rootURL == projectURL)
        #expect(project.isMonorepo == false)
    }
}

@Test func archiveProjectDetectorDetectsMonorepoFromPNPMWorkspaceFile() throws {
    try withTemporaryDirectory { rootURL in
        let projectURL = rootURL.appendingPathComponent("mono", isDirectory: true)
        try createDirectory(at: projectURL)
        try createFile(at: projectURL.appendingPathComponent("pnpm-workspace.yaml"), contents: "packages:\n  - apps/*")

        let detector = ArchiveProjectDetector(fileManager: .default)
        let project = try detector.detectProject(targetPath: projectURL.path)

        #expect(project.type == .node)
        #expect(project.isMonorepo)
    }
}

@Test func archiveProjectDetectorInfersPackageManagerByLockfilePriority() throws {
    try withTemporaryDirectory { rootURL in
        let projectURL = rootURL.appendingPathComponent("pkg", isDirectory: true)
        try createDirectory(at: projectURL)

        let detector = ArchiveProjectDetector(fileManager: .default)

        try createFile(at: projectURL.appendingPathComponent("package-lock.json"), contents: "{}")
        #expect(detector.detectPackageManager(in: projectURL) == .npm)

        try createFile(at: projectURL.appendingPathComponent("yarn.lock"), contents: "")
        #expect(detector.detectPackageManager(in: projectURL) == .yarn)

        try createFile(at: projectURL.appendingPathComponent("pnpm-lock.yaml"), contents: "")
        #expect(detector.detectPackageManager(in: projectURL) == .pnpm)
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickDevArchiveProjectDetectorTests-\(UUID().uuidString)", isDirectory: true)
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
    try Data(contents.utf8).write(to: url)
}
