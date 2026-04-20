import Foundation
import Testing
@testable import QuickDev

@Test func archiveManifestBuilderIncludesSchemaAndRestoreHints() {
    let rootURL = URL(fileURLWithPath: "/tmp/my-project", isDirectory: true)
    let project = ArchiveProjectInfo(
        rootURL: rootURL,
        name: "my-project",
        type: .node,
        isMonorepo: false,
        packageManager: .pnpm
    )
    let plan = PlannedArchive(
        included: [],
        excluded: [],
        warnings: [],
        dotenvPaths: [],
        stats: ArchivePlanStats(
            originalFileCount: 10,
            archivedFileCount: 5,
            originalBytes: 1000,
            includedBytes: 500,
            excludedBytesEstimate: 500
        )
    )

    let fixedDate = Date(timeIntervalSince1970: 1_776_696_000)
    let manifest = ArchiveManifestBuilder(now: { fixedDate }).buildManifest(
        project: project,
        plan: plan,
        git: ArchiveGitInfo(included: true, headCommit: "abc123", branch: "main", dirty: true),
        compression: .max,
        quickdevVersion: "0.0.5",
        archivedBytes: 321
    )

    #expect(manifest.schemaVersion == 1)
    #expect(manifest.restoreHints.packageManager == "pnpm")
    #expect(manifest.restoreHints.commands == ["pnpm install --frozen-lockfile", "pnpm build"])
}

@Test func archiveManifestBuilderReflectsExcludedAndWarningEntries() {
    let rootURL = URL(fileURLWithPath: "/tmp/my-project", isDirectory: true)
    let project = ArchiveProjectInfo(
        rootURL: rootURL,
        name: "my-project",
        type: .node,
        isMonorepo: false,
        packageManager: .npm
    )
    let plan = PlannedArchive(
        included: [],
        excluded: [
            ArchiveExcludedEntry(path: "node_modules", reason: "rebuildable_dependency_directory", category: "dependency"),
        ],
        warnings: [
            ArchiveWarningEntry(path: ".env", reason: "environment_file_detected"),
        ],
        dotenvPaths: [".env"],
        stats: ArchivePlanStats(
            originalFileCount: 10,
            archivedFileCount: 5,
            originalBytes: 1000,
            includedBytes: 500,
            excludedBytesEstimate: 500
        )
    )

    let manifest = ArchiveManifestBuilder().buildManifest(
        project: project,
        plan: plan,
        git: ArchiveGitInfo(included: false, headCommit: nil, branch: nil, dirty: nil),
        compression: .default,
        quickdevVersion: "0.0.5",
        archivedBytes: 250,
        additionalWarnings: [ArchiveWarningEntry(path: "project", reason: "unknown_project_type_detected")]
    )

    #expect(manifest.excluded == plan.excluded)
    #expect(manifest.warnings.contains(where: { $0.path == ".env" && $0.reason == "environment_file_detected" }))
    #expect(manifest.warnings.contains(where: { $0.reason == "unknown_project_type_detected" }))
}
