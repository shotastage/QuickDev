import Foundation

public struct ArchivePolicyBuilder {
    public init() {}

    public func makePolicy(
        project: ArchiveProjectInfo,
        extraExcludePatterns: [String],
        keepGit: Bool
    ) -> ArchivePolicy {
        let includePriorityPatterns = [
            "package.json",
            "package-lock.json",
            "pnpm-lock.yaml",
            "yarn.lock",
            "tsconfig.json",
            "jsconfig.json",
            "vite.config.*",
            "next.config.*",
            "nuxt.config.*",
            ".npmrc",
            ".nvmrc",
            ".node-version",
            "Dockerfile",
            "docker-compose.*",
            ".gitignore",
            "README*",
            "docs/**",
            "src/**",
            "app/**",
            "public/**",
            "scripts/**",
            "prisma/**",
            "migrations/**",
            ".github/**",
            "*.md",
        ]

        let warningPatterns = [
            ".env",
            ".env.*",
            "*.db",
            "*.sqlite",
            "*.sqlite3",
            "data",
            "uploads",
            "storage",
            "secrets",
            "keys",
            "certs",
        ]

        var excludePatterns: [String]
        switch project.type {
        case .node:
            excludePatterns = [
                "node_modules",
                "dist",
                "build",
                "coverage",
                ".next",
                ".nuxt",
                ".turbo",
                ".parcel-cache",
                ".cache",
                ".tmp",
                "tmp",
                "out",
                ".eslintcache",
                ".vite",
                "storybook-static",
                "*.log",
                ".DS_Store",
                "Thumbs.db",
            ]
        case .unknown:
            excludePatterns = [
                ".cache",
                ".tmp",
                "tmp",
                "*.log",
                ".DS_Store",
                "Thumbs.db",
            ]
        }

        if keepGit == false {
            excludePatterns.append(".git")
        }

        excludePatterns.append(contentsOf: extraExcludePatterns)

        return ArchivePolicy(
            includePriorityPatterns: includePriorityPatterns,
            excludePatterns: excludePatterns,
            warningPatterns: warningPatterns,
            userExcludePatterns: extraExcludePatterns
        )
    }
}

enum ArchivePatternMatcher {
    static func matches(path: String, pattern: String, entryType: ArchiveScannedEntryType) -> Bool {
        let normalizedPath = normalize(path)
        let normalizedPattern = normalize(pattern)

        if normalizedPattern.hasSuffix("/**") {
            let prefix = String(normalizedPattern.dropLast(3))
            return normalizedPath == prefix || normalizedPath.hasPrefix(prefix + "/")
        }

        if normalizedPattern.contains("/") == false {
            if normalizedPattern.contains("*") || normalizedPattern.contains("?") {
                let baseName = normalizedPath.split(separator: "/").last.map(String.init) ?? normalizedPath
                return wildcardMatch(baseName, pattern: normalizedPattern)
            }

            let components = normalizedPath.split(separator: "/").map(String.init)
            if entryType == .dir {
                return components.contains(normalizedPattern)
            }

            return components.contains(normalizedPattern)
        }

        if normalizedPattern.contains("*") || normalizedPattern.contains("?") {
            return wildcardMatch(normalizedPath, pattern: normalizedPattern)
        }

        return normalizedPath == normalizedPattern || normalizedPath.hasPrefix(normalizedPattern + "/")
    }

    static func matchesAny(path: String, patterns: [String], entryType: ArchiveScannedEntryType) -> Bool {
        patterns.contains { matches(path: path, pattern: $0, entryType: entryType) }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
    }

    private static func wildcardMatch(_ value: String, pattern: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        let regexPattern = "^\(escaped)$"

        guard let expression = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive]) else {
            return false
        }

        let range = NSRange(location: 0, length: (value as NSString).length)
        return expression.firstMatch(in: value, options: [], range: range) != nil
    }
}
