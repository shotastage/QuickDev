import Foundation

public struct ArchivePlanner {
    public init() {}

    public func plan(
        scannedEntries: [ArchiveScannedEntry],
        policy: ArchivePolicy
    ) -> PlannedArchive {
        let orderedEntries = scannedEntries.sorted { lhs, rhs in
            let lhsDepth = lhs.relativePath.split(separator: "/").count
            let rhsDepth = rhs.relativePath.split(separator: "/").count
            if lhsDepth != rhsDepth {
                return lhsDepth < rhsDepth
            }

            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }

        var included: [ArchiveScannedEntry] = []
        var excluded: [ArchiveExcludedEntry] = []
        var warnings: [ArchiveWarningEntry] = []
        var dotenvPaths: [String] = []
        var excludedDirectoryPrefixes: Set<String> = []

        var originalFileCount = 0
        var archivedFileCount = 0
        var originalBytes: Int64 = 0
        var includedBytes: Int64 = 0

        for entry in orderedEntries {
            if entry.type == .file {
                originalFileCount += 1
                originalBytes += entry.size
            }

            if isInsideExcludedDirectory(path: entry.relativePath, excludedDirectoryPrefixes: excludedDirectoryPrefixes) {
                continue
            }

            if entry.type == .symlink {
                excluded.append(
                    ArchiveExcludedEntry(
                        path: entry.relativePath,
                        reason: "symlink_not_archived",
                        category: "safety"
                    )
                )
                continue
            }

            let isPriorityIncluded = ArchivePatternMatcher.matchesAny(
                path: entry.relativePath,
                patterns: policy.includePriorityPatterns,
                entryType: entry.type
            )

            if isPriorityIncluded == false {
                let exclusionDecision = exclusionMetadata(for: entry, policy: policy)
                if let exclusionDecision {
                    excluded.append(exclusionDecision)
                    if entry.type == .dir {
                        excludedDirectoryPrefixes.insert(entry.relativePath)
                    }
                    continue
                }
            }

            if let warningEntry = warningDecision(for: entry, warningPatterns: policy.warningPatterns) {
                warnings.append(warningEntry)
                if warningEntry.reason == "environment_file_detected" {
                    dotenvPaths.append(warningEntry.path)
                }
            }

            included.append(entry)
            if entry.type == .file {
                archivedFileCount += 1
                includedBytes += entry.size
            }
        }

        let stats = ArchivePlanStats(
            originalFileCount: originalFileCount,
            archivedFileCount: archivedFileCount,
            originalBytes: originalBytes,
            includedBytes: includedBytes,
            excludedBytesEstimate: max(0, originalBytes - includedBytes)
        )

        return PlannedArchive(
            included: included,
            excluded: excluded,
            warnings: uniqueWarnings(warnings),
            dotenvPaths: Array(Set(dotenvPaths)).sorted(),
            stats: stats
        )
    }

    private func exclusionMetadata(for entry: ArchiveScannedEntry, policy: ArchivePolicy) -> ArchiveExcludedEntry? {
        for pattern in policy.excludePatterns {
            if ArchivePatternMatcher.matches(path: entry.relativePath, pattern: pattern, entryType: entry.type) == false {
                continue
            }

            if policy.userExcludePatterns.contains(pattern) {
                return ArchiveExcludedEntry(
                    path: entry.relativePath,
                    reason: "user_excluded_pattern",
                    category: "custom"
                )
            }

            let metadata = inferExcludeMetadata(path: entry.relativePath)
            return ArchiveExcludedEntry(path: entry.relativePath, reason: metadata.reason, category: metadata.category)
        }

        return nil
    }

    private func inferExcludeMetadata(path: String) -> (reason: String, category: String) {
        let baseName = path.split(separator: "/").last.map { String($0).lowercased() } ?? path.lowercased()

        switch baseName {
        case "node_modules":
            return ("rebuildable_dependency_directory", "dependency")
        case "dist", "build", "coverage", ".next", ".nuxt", ".turbo", ".vite", "storybook-static", "out":
            return ("rebuildable_build_output", "build")
        case ".parcel-cache", ".cache", ".tmp", "tmp", ".eslintcache":
            return ("rebuildable_cache_directory", "cache")
        case ".ds_store", "thumbs.db":
            return ("os_generated_file", "system")
        default:
            if baseName.hasSuffix(".log") {
                return ("runtime_log_file", "log")
            }

            return ("policy_excluded_entry", "misc")
        }
    }

    private func warningDecision(for entry: ArchiveScannedEntry, warningPatterns: [String]) -> ArchiveWarningEntry? {
        guard ArchivePatternMatcher.matchesAny(path: entry.relativePath, patterns: warningPatterns, entryType: entry.type) else {
            return nil
        }

        let baseName = entry.relativePath.split(separator: "/").last.map { String($0).lowercased() } ?? ""

        if baseName == ".env" || baseName.hasPrefix(".env.") {
            return ArchiveWarningEntry(path: entry.relativePath, reason: "environment_file_detected")
        }

        if baseName.hasSuffix(".db") || baseName.hasSuffix(".sqlite") || baseName.hasSuffix(".sqlite3") {
            return ArchiveWarningEntry(path: entry.relativePath, reason: "local_database_detected")
        }

        if ["data", "uploads", "storage", "secrets", "keys", "certs"].contains(baseName) {
            return ArchiveWarningEntry(path: entry.relativePath, reason: "sensitive_directory_detected")
        }

        return ArchiveWarningEntry(path: entry.relativePath, reason: "warning_pattern_detected")
    }

    private func isInsideExcludedDirectory(path: String, excludedDirectoryPrefixes: Set<String>) -> Bool {
        excludedDirectoryPrefixes.contains { prefix in
            path == prefix || path.hasPrefix(prefix + "/")
        }
    }

    private func uniqueWarnings(_ warnings: [ArchiveWarningEntry]) -> [ArchiveWarningEntry] {
        var visited: Set<String> = []
        var unique: [ArchiveWarningEntry] = []

        for warning in warnings {
            let key = "\(warning.path)|\(warning.reason)"
            guard visited.contains(key) == false else {
                continue
            }

            visited.insert(key)
            unique.append(warning)
        }

        return unique.sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }
}
