import Foundation
import Testing
@testable import QuickDev

@Test func projectLookupFindsExactNameMatch() throws {
    let index = makeIndex(
        records: [
            makeRecord(name: "Wonderway", path: "/tmp/Developer/Wonderway"),
            makeRecord(name: "Other", path: "/tmp/Developer/Other"),
        ]
    )

    let record = try index.project(named: "Wonderway")
    #expect(record.path == "/tmp/Developer/Wonderway")
}

@Test func projectLookupFallsBackToCaseInsensitiveMatch() throws {
    let index = makeIndex(
        records: [
            makeRecord(name: "Wonderway", path: "/tmp/Developer/Wonderway"),
        ]
    )

    let record = try index.project(named: "wonderway")
    #expect(record.name == "Wonderway")
}

@Test func projectLookupThrowsWhenProjectDoesNotExist() throws {
    let index = makeIndex(
        records: [
            makeRecord(name: "Wonderway", path: "/tmp/Developer/Wonderway"),
        ]
    )

    #expect(throws: ProjectIndexLookupError.projectNotFound("Missing")) {
        _ = try index.project(named: "Missing")
    }
}

@Test func projectLookupThrowsWhenCaseInsensitiveMatchesAreAmbiguous() throws {
    let index = makeIndex(
        records: [
            makeRecord(name: "Wonderway", path: "/tmp/Developer/Wonderway"),
            makeRecord(name: "wonderway", path: "/tmp/Developer/Nested/wonderway"),
        ]
    )

    do {
        _ = try index.project(named: "WONDERWAY")
        #expect(Bool(false), "Expected an ambiguous project name error.")
    } catch let error as ProjectIndexLookupError {
        switch error {
        case .ambiguousProjectName(let name, let matches):
            #expect(name == "WONDERWAY")
            #expect(Set(matches) == Set([
                "Wonderway (Wonderway)",
                "wonderway (Nested/wonderway)",
            ]))
        default:
            #expect(Bool(false), "Unexpected lookup error: \(error)")
        }
    }
}

private func makeIndex(records: [ProjectRecord]) -> ProjectIndex {
    ProjectIndex(
        version: 1,
        rootPath: "/tmp/Developer",
        scannedAt: Date(timeIntervalSince1970: 1_744_000_000),
        projects: records
    )
}

private func makeRecord(name: String, path: String) -> ProjectRecord {
    ProjectRecord(
        id: UUID(),
        name: name,
        path: path,
        relativePathFromRoot: relativePath(path: path),
        lastModifiedAt: Date(timeIntervalSince1970: 1_744_000_000),
        detectedTypes: [.unknown],
        isGitRepository: false,
        gitRemoteURL: nil,
        hasUncommittedChanges: nil,
        primaryLanguage: nil,
        sizeBytes: nil,
        status: .active,
        scannedAt: Date(timeIntervalSince1970: 1_744_000_000)
    )
}

private func relativePath(path: String) -> String {
    let prefix = "/tmp/Developer/"
    if path.hasPrefix(prefix) {
        return String(path.dropFirst(prefix.count))
    }
    return NSString(string: path).lastPathComponent
}
