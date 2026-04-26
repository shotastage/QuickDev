import Foundation
import Testing
@testable import QuickDev

@Test func archivePlannerExcludesNodeModulesAndKeepsSourceDirectory() {
    let policy = ArchivePolicyBuilder().makePolicy(
        project: ArchiveProjectInfo(
            rootURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true),
            name: "project",
            type: .node,
            isMonorepo: false,
            packageManager: .pnpm
        ),
        extraExcludePatterns: [],
        keepGit: true
    )

    let scannedEntries: [ArchiveScannedEntry] = [
        .init(relativePath: "node_modules", absolutePath: "/tmp/project/node_modules", type: .dir, size: 0),
        .init(relativePath: "node_modules/react/index.js", absolutePath: "/tmp/project/node_modules/react/index.js", type: .file, size: 100),
        .init(relativePath: "src", absolutePath: "/tmp/project/src", type: .dir, size: 0),
        .init(relativePath: "src/main.ts", absolutePath: "/tmp/project/src/main.ts", type: .file, size: 20),
    ]

    let plan = ArchivePlanner().plan(scannedEntries: scannedEntries, policy: policy)

    #expect(plan.excluded.contains(where: { $0.path == "node_modules" && $0.category == "dependency" }))
    #expect(plan.included.contains(where: { $0.relativePath == "src/main.ts" }))
    #expect(plan.included.contains(where: { $0.relativePath == "node_modules/react/index.js" }) == false)
}

@Test func archivePlannerAddsWarningsForDotenvAndDatabaseFiles() {
    let policy = ArchivePolicyBuilder().makePolicy(
        project: ArchiveProjectInfo(
            rootURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true),
            name: "project",
            type: .node,
            isMonorepo: false,
            packageManager: .npm
        ),
        extraExcludePatterns: [],
        keepGit: true
    )

    let scannedEntries: [ArchiveScannedEntry] = [
        .init(relativePath: ".env", absolutePath: "/tmp/project/.env", type: .file, size: 12),
        .init(relativePath: "data/app.db", absolutePath: "/tmp/project/data/app.db", type: .file, size: 80),
    ]

    let plan = ArchivePlanner().plan(scannedEntries: scannedEntries, policy: policy)

    #expect(plan.warnings.contains(where: { $0.path == ".env" && $0.reason == "environment_file_detected" }))
    #expect(plan.warnings.contains(where: { $0.path == "data/app.db" && $0.reason == "local_database_detected" }))
    #expect(plan.included.count == 2)
}

@Test func archivePlannerPrefersIncludePatternsOverExcludePatterns() {
    let policy = ArchivePolicyBuilder().makePolicy(
        project: ArchiveProjectInfo(
            rootURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true),
            name: "project",
            type: .node,
            isMonorepo: false,
            packageManager: .npm
        ),
        extraExcludePatterns: [],
        keepGit: true
    )

    let scannedEntries: [ArchiveScannedEntry] = [
        .init(relativePath: "src/build/output.js", absolutePath: "/tmp/project/src/build/output.js", type: .file, size: 20),
    ]

    let plan = ArchivePlanner().plan(scannedEntries: scannedEntries, policy: policy)

    #expect(plan.included.contains(where: { $0.relativePath == "src/build/output.js" }))
    #expect(plan.excluded.isEmpty)
}
