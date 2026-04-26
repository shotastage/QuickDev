import Foundation

public enum ArchiveProjectType: String, Codable, Sendable {
    case node
    case unknown
}

public enum ArchivePackageManager: String, Codable, Sendable {
    case npm
    case pnpm
    case yarn
}

public enum ArchiveCompressionLevel: String, Codable, Sendable {
    case `default`
    case max
}

public enum ArchiveFormat: String, Codable, Sendable {
    case qda
}

public struct ArchiveProjectInfo: Equatable, Sendable {
    public let rootURL: URL
    public let name: String
    public let type: ArchiveProjectType
    public let isMonorepo: Bool
    public let packageManager: ArchivePackageManager?

    public init(
        rootURL: URL,
        name: String,
        type: ArchiveProjectType,
        isMonorepo: Bool,
        packageManager: ArchivePackageManager?
    ) {
        self.rootURL = rootURL
        self.name = name
        self.type = type
        self.isMonorepo = isMonorepo
        self.packageManager = packageManager
    }
}

public struct ArchivePolicy: Equatable, Sendable {
    public let includePriorityPatterns: [String]
    public let excludePatterns: [String]
    public let warningPatterns: [String]
    let userExcludePatterns: [String]

    public init(
        includePriorityPatterns: [String],
        excludePatterns: [String],
        warningPatterns: [String],
        userExcludePatterns: [String] = []
    ) {
        self.includePriorityPatterns = includePriorityPatterns
        self.excludePatterns = excludePatterns
        self.warningPatterns = warningPatterns
        self.userExcludePatterns = userExcludePatterns
    }
}

public enum ArchiveScannedEntryType: String, Equatable, Sendable {
    case file
    case dir
    case symlink
}

public struct ArchiveScannedEntry: Equatable, Sendable {
    public let relativePath: String
    public let absolutePath: String
    public let type: ArchiveScannedEntryType
    public let size: Int64

    public init(relativePath: String, absolutePath: String, type: ArchiveScannedEntryType, size: Int64) {
        self.relativePath = relativePath
        self.absolutePath = absolutePath
        self.type = type
        self.size = size
    }
}

public struct ArchiveExcludedEntry: Equatable, Codable, Sendable {
    public let path: String
    public let reason: String
    public let category: String

    public init(path: String, reason: String, category: String) {
        self.path = path
        self.reason = reason
        self.category = category
    }
}

public struct ArchiveWarningEntry: Equatable, Codable, Sendable {
    public let path: String
    public let reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public struct ArchivePlanStats: Equatable, Sendable {
    public let originalFileCount: Int
    public let archivedFileCount: Int
    public let originalBytes: Int64
    public let includedBytes: Int64
    public let excludedBytesEstimate: Int64

    public init(
        originalFileCount: Int,
        archivedFileCount: Int,
        originalBytes: Int64,
        includedBytes: Int64,
        excludedBytesEstimate: Int64
    ) {
        self.originalFileCount = originalFileCount
        self.archivedFileCount = archivedFileCount
        self.originalBytes = originalBytes
        self.includedBytes = includedBytes
        self.excludedBytesEstimate = excludedBytesEstimate
    }
}

public struct PlannedArchive: Equatable, Sendable {
    public let included: [ArchiveScannedEntry]
    public let excluded: [ArchiveExcludedEntry]
    public let warnings: [ArchiveWarningEntry]
    public let dotenvPaths: [String]
    public let stats: ArchivePlanStats

    public init(
        included: [ArchiveScannedEntry],
        excluded: [ArchiveExcludedEntry],
        warnings: [ArchiveWarningEntry],
        dotenvPaths: [String],
        stats: ArchivePlanStats
    ) {
        self.included = included
        self.excluded = excluded
        self.warnings = warnings
        self.dotenvPaths = dotenvPaths
        self.stats = stats
    }
}

public struct ArchiveGitInfo: Equatable, Codable, Sendable {
    public let included: Bool
    public let headCommit: String?
    public let branch: String?
    public let dirty: Bool?

    public init(included: Bool, headCommit: String?, branch: String?, dirty: Bool?) {
        self.included = included
        self.headCommit = headCommit
        self.branch = branch
        self.dirty = dirty
    }
}

public struct ArchiveManifest: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let createdAt: String
    public let quickdevVersion: String
    public let archiveFormat: String
    public let compression: String
    public let project: Project
    public let git: ArchiveGitInfo
    public let stats: Stats
    public let excluded: [ArchiveExcludedEntry]
    public let warnings: [ArchiveWarningEntry]
    public let restoreHints: RestoreHints

    public struct Project: Equatable, Codable, Sendable {
        public let name: String
        public let originalPath: String
        public let detectedType: String
        public let isMonorepo: Bool

        public init(name: String, originalPath: String, detectedType: String, isMonorepo: Bool) {
            self.name = name
            self.originalPath = originalPath
            self.detectedType = detectedType
            self.isMonorepo = isMonorepo
        }
    }

    public struct Stats: Equatable, Codable, Sendable {
        public let originalFileCount: Int
        public let archivedFileCount: Int
        public let originalBytes: Int64
        public let archivedBytes: Int64
        public let excludedBytesEstimate: Int64

        public init(
            originalFileCount: Int,
            archivedFileCount: Int,
            originalBytes: Int64,
            archivedBytes: Int64,
            excludedBytesEstimate: Int64
        ) {
            self.originalFileCount = originalFileCount
            self.archivedFileCount = archivedFileCount
            self.originalBytes = originalBytes
            self.archivedBytes = archivedBytes
            self.excludedBytesEstimate = excludedBytesEstimate
        }
    }

    public struct RestoreHints: Equatable, Codable, Sendable {
        public let packageManager: String
        public let commands: [String]

        public init(packageManager: String, commands: [String]) {
            self.packageManager = packageManager
            self.commands = commands
        }
    }

    public init(
        schemaVersion: Int,
        createdAt: String,
        quickdevVersion: String,
        archiveFormat: String,
        compression: String,
        project: Project,
        git: ArchiveGitInfo,
        stats: Stats,
        excluded: [ArchiveExcludedEntry],
        warnings: [ArchiveWarningEntry],
        restoreHints: RestoreHints
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.quickdevVersion = quickdevVersion
        self.archiveFormat = archiveFormat
        self.compression = compression
        self.project = project
        self.git = git
        self.stats = stats
        self.excluded = excluded
        self.warnings = warnings
        self.restoreHints = restoreHints
    }
}

public struct ArchiveWriteResult: Equatable, Sendable {
    public let outputURL: URL
    public let archivedBytes: Int64

    public init(outputURL: URL, archivedBytes: Int64) {
        self.outputURL = outputURL
        self.archivedBytes = archivedBytes
    }
}

public struct ArchiveRestoreInspection: Equatable, Sendable {
    public let archiveURL: URL
    public let manifest: ArchiveManifest
    public let payloadEntries: [String]

    public init(archiveURL: URL, manifest: ArchiveManifest, payloadEntries: [String]) {
        self.archiveURL = archiveURL
        self.manifest = manifest
        self.payloadEntries = payloadEntries
    }
}

public struct ArchiveRestoreResult: Equatable, Sendable {
    public let destinationURL: URL
    public let manifest: ArchiveManifest
    public let restoredFileCount: Int

    public init(destinationURL: URL, manifest: ArchiveManifest, restoredFileCount: Int) {
        self.destinationURL = destinationURL
        self.manifest = manifest
        self.restoredFileCount = restoredFileCount
    }
}
