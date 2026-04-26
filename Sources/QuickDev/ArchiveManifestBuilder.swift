import Foundation

public struct ArchiveManifestBuilder {
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Builds the archive manifest that is embedded under meta/archive.json.
    public func buildManifest(
        project: ArchiveProjectInfo,
        plan: PlannedArchive,
        git: ArchiveGitInfo,
        compression: ArchiveCompressionLevel,
        quickdevVersion: String,
        archivedBytes: Int64,
        additionalWarnings: [ArchiveWarningEntry] = []
    ) -> ArchiveManifest {
        let packageManager = project.packageManager ?? .npm
        let warnings = (plan.warnings + additionalWarnings)
            .sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }

        return ArchiveManifest(
            schemaVersion: 1,
            createdAt: iso8601String(from: now()),
            quickdevVersion: quickdevVersion,
            archiveFormat: ArchiveFormat.qda.rawValue,
            compression: compression.rawValue,
            project: .init(
                name: project.name,
                originalPath: project.rootURL.path,
                detectedType: project.type.rawValue,
                isMonorepo: project.isMonorepo
            ),
            git: git,
            stats: .init(
                originalFileCount: plan.stats.originalFileCount,
                archivedFileCount: plan.stats.archivedFileCount,
                originalBytes: plan.stats.originalBytes,
                archivedBytes: archivedBytes,
                excludedBytesEstimate: plan.stats.excludedBytesEstimate
            ),
            excluded: plan.excluded.sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            },
            warnings: warnings,
            restoreHints: .init(
                packageManager: packageManager.rawValue,
                commands: restoreCommands(packageManager: packageManager)
            )
        )
    }

    /// Produces baseline restore command hints for lockfile-based Node projects.
    public func restoreCommands(packageManager: ArchivePackageManager) -> [String] {
        switch packageManager {
        case .pnpm:
            return [
                "pnpm install --frozen-lockfile",
                "pnpm build",
            ]
        case .yarn:
            return [
                "yarn install --immutable",
                "yarn build",
            ]
        case .npm:
            return [
                "npm ci",
                "npm run build",
            ]
        }
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
